# Laboratori de Servidors de Correu — Etapa 5: Segon servidor Stalwart + Roundcube

## Objectiu

Desplegar un segon servidor de correu — **Stalwart Mail Server** — per al domini `professorat.demoasixcloud2025.cat`, configurar-lo amb TLS i els registres d'autenticació DNS (SPF, DKIM, DMARC), i posar en marxa **Roundcube** com a client webmail i un segon **Thunderbird** com a client d'escriptori. Aquesta etapa permet comparar dues arquitectures de servidor de correu completament diferents: docker-mailserver (DMS) basat en Postfix+Dovecot i Stalwart, un servidor modern escrit en Rust amb suport natiu per a JMAP.

---

## Arquitectura de la xarxa

```
Host Linux (tu)
  │
  ├─ http://localhost:8080  → Proxy Nginx (índex serveis)
  ├─ http://localhost:5800  → Thunderbird 1 (noVNC, alumnat)
  ├─ http://localhost:5801  → Thunderbird 2 (noVNC, professorat)
  └─ http://localhost:8081  → Roundcube (webmail professorat)

  Xarxa LAN: 10.26.50.0/24
  ┌──────────────────────────────────────────────────────────────────────────┐
  │                                                                          │
  │  [switch-lan]              Linux bridge (switch L2)                      │
  │       │                                                                  │
  │       ├── [router-frr]        10.26.50.1   Gateway (FRRouting)           │
  │       ├── [coredns]           10.26.50.2   DNS intern                    │
  │       ├── [proxy]             10.26.50.3   Nginx reverse proxy           │
  │       │                                                                  │
  │       ├── [mail-alumnat]      10.26.50.10  DMS + Rspamd (alumnat)        │
  │       ├── [mail-professorat]  10.26.50.20  Stalwart (professorat)   ←NOU │
  │       │                                                                  │
  │       ├── [thunderbird1]      10.26.50.100 Client correu (alumnat)       │
  │       ├── [thunderbird2]      10.26.50.101 Client correu (professorat) ←NOU│
  │       ├── [roundcube]         10.26.50.102 Webmail (professorat)    ←NOU │
  │       │                                                                  │
  │       ├── [acme]              10.26.50.250 Certificats Let's Encrypt     │
  │       └── [client-swaks]      10.26.50.200 Client CLI (swaks)            │
  │                                                                          │
  └──────────────────────────────────────────────────────────────────────────┘

  Dominis:
    alumnat.demoasixcloud2025.cat     → 10.26.50.10 (DMS)
    professorat.demoasixcloud2025.cat → 10.26.50.20 (Stalwart)

  Accés via proxy:
    thunderbird1.demoasixcloud2025.cat         → Thunderbird 1
    thunderbird2.demoasixcloud2025.cat         → Thunderbird 2
    roundcube.demoasixcloud2025.cat            → Roundcube webmail
    admin.professorat.demoasixcloud2025.cat    → Stalwart Admin UI
```

---

## Prerequisits

- Etapa 4 completada correctament (DMS amb DKIM/DMARC/SPF funcionant)
- Token de Cloudflare API (`CF_DNS_API_TOKEN`) configurat al fitxer `.env`
- Familiaritat amb els conceptes SPF, DKIM i DMARC de l'etapa anterior
- Coneixement bàsic d'IMAP i SMTP (ports, TLS vs STARTTLS)

---

## Pas 1: Generar certificats TLS per al domini professorat

Abans de desplegar, cal generar certificats Let's Encrypt per al nou domini. Si ja tens certificats per a `alumnat`, ara n'afegirem per a `professorat`:

```bash
./lab.sh certs "alumnat professorat"
```

Això utilitza el contenidor ACME amb validació DNS via Cloudflare per generar certificats per a:
- `mail.alumnat.demoasixcloud2025.cat`
- `mail.professorat.demoasixcloud2025.cat`

Verifica que els certificats s'han creat:

```bash
ls -la certs/professorat/
```

Hauries de veure `fullchain.pem` i `key.pem`.

---

## Pas 2: Desplegar la topologia de l'etapa 5

La topologia de l'etapa 5 afegeix tres nodes nous: `mail-professorat` (Stalwart), `thunderbird2` i `roundcube`.

```bash
./lab.sh deploy 5
```

Verifica que tots els nodes estan actius:

```bash
./lab.sh status
```

Hauries de veure 10 nodes: els 7 anteriors més `mail-professorat`, `thunderbird2` i `roundcube`.

---

## Pas 3: Executar el setup (comptes DMS + Stalwart)

El setup de l'etapa 5 realitza tres accions:
1. Crea els comptes d'alumnat a DMS (com a les etapes anteriors)
2. Genera les claus DKIM per a DMS
3. Configura Stalwart: crea el domini `professorat.demoasixcloud2025.cat` i els comptes `profe1` i `profe2` via l'API REST

```bash
./lab.sh setup 5
```

Espera uns 2-3 minuts fins que tots els serveis estiguin operatius.

---

## Pas 4: Verificar Stalwart i accedir a l'administració

Stalwart té una interfície web d'administració integrada. Accedeix-hi a través del proxy:

```
http://admin.professorat.demoasixcloud2025.cat
```

O directament (si tens accés a la xarxa del lab):

```
http://10.26.50.20:8080
```

**Credencials d'administrador:**
- **Usuari:** `admin`
- **Contrasenya:** `Admin.2025`

Des de la interfície d'administració pots:
- Veure els dominis configurats
- Gestionar comptes d'usuari
- Configurar DKIM, TLS i altres paràmetres
- Consultar els registres (logs) del servidor

> **Nota:** L'API REST de Stalwart (usada per l'script de setup) i la interfície web són el mateix punt d'accés (`port 8080`). La interfície web és un frontend JavaScript que crida l'API.

---

## Pas 5: Verificar els comptes creats a Stalwart

Comprova que els comptes d'usuari s'han creat correctament. Pots fer-ho des de la interfície web (secció *Accounts*) o via l'API:

```bash
curl -s -u admin:Admin.2025 \
    http://10.26.50.20:8080/api/account/profe1@professorat.demoasixcloud2025.cat \
    | python3 -m json.tool
```

Hauries de veure les dades del compte `profe1` amb el seu correu electrònic associat.

Comptes creats per l'script de setup:

| Compte | Contrasenya |
|--------|-------------|
| `profe1@professorat.demoasixcloud2025.cat` | `Profe1.2025` |
| `profe2@professorat.demoasixcloud2025.cat` | `Profe2.2025` |

---

## Pas 6: Configurar DNS per al domini professorat a Cloudflare

De la mateixa manera que a l'etapa 4, cal publicar els registres SPF, DKIM i DMARC per al nou domini. Accedeix al panell de Cloudflare.

### 6.1 Registre MX

Verifica que ja existeix (hauria d'estar configurat des d'etapes anteriors):

| Tipus | Nom | Contingut | Prioritat |
|-------|-----|-----------|-----------|
| MX | `professorat.demoasixcloud2025.cat` | `mail.professorat.demoasixcloud2025.cat` | 10 |

### 6.2 Registre SPF

| Tipus | Nom | Contingut |
|-------|-----|-----------|
| TXT | `professorat.demoasixcloud2025.cat` | `v=spf1 mx ~all` |

### 6.3 Registre DKIM

Stalwart genera les claus DKIM automàticament. Obtén la clau pública des de la interfície d'administració (secció *Settings → DKIM*) o via l'API. Crea el registre:

| Tipus | Nom | Contingut |
|-------|-----|-----------|
| TXT | `mail._domainkey.professorat.demoasixcloud2025.cat` | `v=DKIM1; k=rsa; p=...` (clau pública de Stalwart) |

### 6.4 Registre DMARC

| Tipus | Nom | Contingut |
|-------|-----|-----------|
| TXT | `_dmarc.professorat.demoasixcloud2025.cat` | `v=DMARC1; p=none; rua=mailto:postmaster@professorat.demoasixcloud2025.cat` |

---

## Pas 7: Configurar i accedir a Roundcube

Roundcube és un client de correu web (webmail) que es connecta al servidor de correu via IMAP i SMTP. Està preconfigurat per connectar-se a Stalwart (`10.26.50.20`).

### 7.1 Accedir a Roundcube

Obre el navegador i accedeix a:

```
http://roundcube.demoasixcloud2025.cat
```

O directament: `http://localhost:8081`

### 7.2 Iniciar sessió

- **Usuari:** `profe1@professorat.demoasixcloud2025.cat`
- **Contrasenya:** `Profe1.2025`

La configuració del contenidor Roundcube ja defineix:
- `ROUNDCUBEMAIL_DEFAULT_HOST=10.26.50.20` (servidor IMAP = Stalwart)
- `ROUNDCUBEMAIL_DEFAULT_PORT=143` (IMAP sense TLS dins la xarxa interna)
- `ROUNDCUBEMAIL_SMTP_SERVER=10.26.50.20` (servidor SMTP = Stalwart)
- `ROUNDCUBEMAIL_SMTP_PORT=587` (submission amb STARTTLS)

### 7.3 Explorar la interfície

Roundcube ofereix:
- Bústia d'entrada, carpetes (Sent, Drafts, Trash, Junk)
- Composició de missatges amb format HTML
- Gestió de contactes
- Configuració del compte

---

## Pas 8: Enviar correu entre profe1 i profe2 via Roundcube

### 8.1 Enviar correu des de profe1

Amb la sessió de `profe1` oberta a Roundcube:

1. Fes clic a **Compose** (Redactar)
2. **To:** `profe2@professorat.demoasixcloud2025.cat`
3. **Subject:** `Prova Roundcube etapa 5`
4. **Cos:** `Hola profe2, aquest correu s'envia des de Roundcube via Stalwart.`
5. Fes clic a **Send**

### 8.2 Verificar la recepció

Tanca la sessió de `profe1` i inicia sessió amb `profe2`:

- **Usuari:** `profe2@professorat.demoasixcloud2025.cat`
- **Contrasenya:** `Profe2.2025`

Hauries de veure el missatge a la bústia d'entrada. Obre'l i verifica que el contingut és correcte.

---

## Pas 9: Configurar Thunderbird 2 per al domini professorat

Accedeix a Thunderbird 2 via el navegador:

```
http://localhost:5801
```

O via el proxy: `http://thunderbird2.demoasixcloud2025.cat`

### 9.1 Configurar el compte

Afegeix un compte de correu nou amb les dades:

| Camp | Valor |
|------|-------|
| **Nom** | Professor 1 |
| **Correu** | `profe1@professorat.demoasixcloud2025.cat` |
| **Contrasenya** | `Profe1.2025` |

### 9.2 Configuració manual del servidor

Si l'autoconfiguració no funciona, configura manualment:

| Protocol | Servidor | Port | Seguretat | Autenticació |
|----------|----------|------|-----------|-------------|
| **IMAP** | `10.26.50.20` | 143 | STARTTLS o Cap | Password normal |
| **SMTP** | `10.26.50.20` | 587 | STARTTLS | Password normal |

### 9.3 Verificar

Envia un correu des de Thunderbird 2 a `profe2@professorat.demoasixcloud2025.cat` i comprova que arriba a Roundcube (o viceversa).

---

## Pas 10: Comparar DMS i Stalwart

Ara que tenim dos servidors de correu funcionant, és el moment de comparar-ne les diferències arquitecturals i funcionals.

### 10.1 Comparativa tècnica

| Característica | docker-mailserver (DMS) | Stalwart |
|---------------|------------------------|----------|
| **Llenguatge** | Bash/scripts + C (Postfix, Dovecot) | Rust |
| **Components** | Postfix + Dovecot + Rspamd + ... | Servidor monolític integrat |
| **Contenidors** | 1 (amb múltiples processos interns) | 1 |
| **Configuració** | Variables d'entorn + fitxers | `config.toml` + API REST + Web UI |
| **Protocols** | SMTP, IMAP, POP3 | SMTP, IMAP, POP3, JMAP, ManageSieve |
| **Base de dades** | Fitxers plans (mbox/Maildir) | RocksDB (embedded) |
| **DKIM** | OpenDKIM o Rspamd | Integrat nativament |
| **Administració** | CLI (`setup` command) | Web UI + API REST |
| **Anti-spam** | Rspamd / SpamAssassin | Integrat (sieve filters) |
| **TLS** | Manual (fitxers PEM) | Manual o ACME integrat |

### 10.2 Diferències clau

- **DMS** és un *metapaquet* que empaqueta eines Unix clàssiques (Postfix, Dovecot, Rspamd, ClamAV) dins d'un sol contenidor Docker. Cada servei intern és un procés separat gestionat per `supervisord`.

- **Stalwart** és un servidor escrit des de zero en Rust que implementa tots els protocols en un sol binari. No depèn de Postfix ni Dovecot. Això el fa més lleuger però menys flexible per a personalitzacions avançades.

- **JMAP** (JSON Meta Application Protocol) és un protocol modern que Stalwart suporta de forma nativa. És una alternativa a IMAP dissenyada per a clients web, amb una API basada en JSON sobre HTTP.

---

## Pas 11: Verificar amb swaks l'enviament al servidor Stalwart

Utilitza swaks per enviar un correu directament al servidor Stalwart i comprovar que el rep correctament:

```bash
docker exec clab-mailserver-lab-client-swaks \
    swaks \
    --to profe1@professorat.demoasixcloud2025.cat \
    --from test@example.com \
    --server 10.26.50.20 \
    --port 25 \
    --header "Subject: Prova swaks a Stalwart" \
    --body "Missatge enviat directament a Stalwart via swaks."
```

Verifica la recepció a Roundcube o Thunderbird 2 amb el compte `profe1`.

> **Nota:** En aquest cas enviem sense autenticació al port 25 (MTA-to-MTA). En producció, el port 25 només accepta correus destinats al domini local. Per enviar correu com a usuari autenticat, cal usar el port 587 (submission) amb credencials.

---

## Resum de l'Etapa 5

| Node nou | IP | Servei | Funció |
|----------|----|--------|--------|
| `mail-professorat` | 10.26.50.20 | Stalwart Mail Server | Servidor de correu per a `professorat.(...)` |
| `thunderbird2` | 10.26.50.101 | Thunderbird (noVNC) | Client d'escriptori per a professorat |
| `roundcube` | 10.26.50.102 | Roundcube Webmail | Client webmail per a professorat |

| Accés | URL |
|-------|-----|
| Thunderbird 1 (alumnat) | `http://localhost:5800` |
| Thunderbird 2 (professorat) | `http://localhost:5801` |
| Roundcube (professorat) | `http://localhost:8081` |
| Stalwart Admin | `http://admin.professorat.demoasixcloud2025.cat` via proxy |

| Fitxer de configuració | Descripció |
|----------------------|------------|
| `topologies/etapa5.yml` | Topologia Containerlab amb els 10 nodes |
| `configs/stalwart/etapa5/config.toml` | Configuració de Stalwart (listeners, TLS, storage) |
| `configs/stalwart/etapa5/setup-stalwart.sh` | Script de creació de domini i comptes via API |
| `configs/nginx/etapa5.conf` | Proxy invers amb rutes per Roundcube i Stalwart admin |

---

## Observacions importants

1. **Els dominis estan aïllats.** En aquest laboratori, `alumnat.(...)` i `professorat.(...)` no es comuniquen entre ells. Cada servidor de correu gestiona únicament el seu domini. Això és una limitació intencionada del lab per simplicitat.

2. **Stalwart usa RocksDB** com a base de dades embedded. A diferència de DMS (que usa fitxers Maildir), Stalwart emmagatzema tot — correus, índexs, metadades — en una base de dades clau-valor de tipus LSM-tree. Això ofereix millor rendiment però fa la depuració manual més difícil.

3. **Roundcube és un client, no un servidor.** Roundcube no emmagatzema correus. Es connecta al servidor via IMAP per llegir-los i via SMTP per enviar-los. Si el servidor cau, Roundcube no pot funcionar.

4. **L'API REST de Stalwart** permet automatitzar completament l'administració: crear dominis, comptes, claus DKIM, consultar registres, etc. Això contrasta amb DMS, on l'administració es fa via la comanda `setup` dins del contenidor.

5. **La configuració `config.toml`** de Stalwart defineix els listeners (ports), el TLS, l'emmagatzematge i l'autenticació. A diferència de DMS (on tot es controla per variables d'entorn), Stalwart usa un fitxer TOML que ofereix més granularitat.

6. **Thunderbird i Roundcube accedeixen al mateix servidor** (Stalwart), però per protocols lleugerament diferents. Thunderbird usa IMAP directament; Roundcube també usa IMAP però actua com a intermediari web.

---

## Preguntes de reflexió — Etapa 5

1. Quines diferències arquitecturals hi ha entre docker-mailserver (DMS) i Stalwart? Compara el model de *múltiples processos Unix empaquetats* (DMS) amb el model de *servidor monolític en Rust* (Stalwart). Quins avantatges i inconvenients té cadascun?

2. Què és Roundcube i en què es diferencia de Thunderbird? Compara un client webmail (Roundcube) amb un client d'escriptori (Thunderbird) en termes de funcionalitat, seguretat, dependència del servidor i experiència d'usuari.

3. Com gestiona Stalwart el DKIM en comparació amb DMS? A DMS cal activar Rspamd o OpenDKIM; a Stalwart el DKIM és integrat nativament. Quins avantatges té la integració nativa? Quins riscos pot suposar no poder triar l'eina de signatura?

4. Per quina raó pot ser útil tenir múltiples servidors de correu per a diferents dominis dins d'una mateixa organització? Pensa en separació de responsabilitats, seguretat, requisits regulatoris i escalabilitat.

5. Com funcionen els registres MX per enrutar el correu al servidor correcte? Si un correu s'envia a `profe1@professorat.(...)`, descriu pas a pas com el servidor emissor descobreix que ha de connectar-se a `10.26.50.20`.

6. Què és JMAP i com es compara amb IMAP? Descriu els avantatges de JMAP (basat en JSON/HTTP) per a clients web moderns i els motius pels quals IMAP encara domina en clients d'escriptori.

7. Compara la interfície d'administració web de Stalwart amb l'enfocament CLI de DMS (comanda `setup`). En quins escenaris preferiries un enfocament o l'altre? Com afecta l'automatització (scripts, CI/CD)?

8. Com es diferencia la configuració via `config.toml` (Stalwart) de la configuració via variables d'entorn (DMS)? Quines implicacions té per a la portabilitat, el versionat (git) i la depuració?

9. Què és RocksDB i com es diferencia de l'emmagatzematge en fitxers plans (Maildir) que usa DMS? Quins avantatges ofereix una base de dades embedded per a un servidor de correu? Quins inconvenients pot tenir per a la recuperació de dades?

10. Com provaries la connectivitat entre els dos servidors de correu (`alumnat` i `professorat`) si els dominis no estan aïllats? Descriu les proves que faries amb `swaks`, `telnet` o `openssl s_client` per verificar que el correu es lliura correctament entre dominis.
