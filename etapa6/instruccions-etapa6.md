# Laboratori de Servidors de Correu — Etapa 6: Tercer servidor Mailcow

## Objectiu

Desplegar **Mailcow** per al domini `alumni.demoasixcloud2025.cat`, comprendre la seva arquitectura multi-contenidor (microserveis) i realitzar una comparativa completa dels tres servidors de correu del laboratori: **docker-mailserver (DMS)**, **Stalwart** i **Mailcow**. Aquesta etapa culmina el laboratori amb una visió panoràmica de les diferents aproximacions per a l'administració de servidors de correu electrònic.

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
  │       ├── [mail-professorat]  10.26.50.20  Stalwart (professorat)        │
  │       ├── [mail-alumni]       10.26.50.30  Mailcow (alumni)         ←NOU │
  │       │                                                                  │
  │       ├── [thunderbird1]      10.26.50.100 Client correu (alumnat)       │
  │       ├── [thunderbird2]      10.26.50.101 Client correu (professorat)   │
  │       ├── [roundcube]         10.26.50.102 Webmail (professorat)         │
  │       │                                                                  │
  │       ├── [acme]              10.26.50.250 Certificats Let's Encrypt     │
  │       └── [client-swaks]      10.26.50.200 Client CLI (swaks)            │
  │                                                                          │
  └──────────────────────────────────────────────────────────────────────────┘

  Dominis:
    alumnat.demoasixcloud2025.cat     → 10.26.50.10 (DMS)          1 contenidor
    professorat.demoasixcloud2025.cat → 10.26.50.20 (Stalwart)     1 contenidor
    alumni.demoasixcloud2025.cat      → 10.26.50.30 (Mailcow)      ~12 contenidors

  Arquitectura interna de Mailcow (mail-alumni):
  ┌─────────────────────────────────────────────────────┐
  │  mail-alumni (10.26.50.30) — Stack Mailcow          │
  │                                                     │
  │  ┌─────────┐  ┌──────────┐  ┌──────────┐           │
  │  │ Postfix  │  │ Dovecot  │  │  Nginx   │           │
  │  │ (SMTP)   │  │ (IMAP)   │  │ (proxy)  │           │
  │  └────┬─────┘  └────┬─────┘  └────┬─────┘           │
  │       │             │             │                  │
  │  ┌────┴─────┐  ┌────┴─────┐  ┌────┴─────┐           │
  │  │ Rspamd   │  │ MariaDB  │  │ SOGo     │           │
  │  │(antispam)│  │ (BBDD)   │  │(webmail) │           │
  │  └──────────┘  └──────────┘  └──────────┘           │
  │                                                     │
  │  ┌──────────┐  ┌──────────┐  ┌──────────┐           │
  │  │  Redis   │  │ PHP-FPM  │  │  ClamAV  │           │
  │  │ (cache)  │  │ (admin)  │  │(antivirus)│          │
  │  └──────────┘  └──────────┘  └──────────┘           │
  └─────────────────────────────────────────────────────┘
```

---

## Prerequisits

- Etapa 5 completada correctament (DMS + Stalwart funcionant)
- Token de Cloudflare API (`CF_DNS_API_TOKEN`) configurat al fitxer `.env`
- Mínim 8 GB de RAM disponible al host (Mailcow és intensiu en recursos)
- Docker Compose instal·lat (Mailcow requereix `docker compose` per al seu stack)
- Familiaritat amb els conceptes de microserveis i orquestració de contenidors

---

## Pas 1: Generar certificats TLS per a tots els dominis

Genera certificats Let's Encrypt per als tres dominis:

```bash
./lab.sh certs "alumnat professorat alumni"
```

Verifica que els certificats s'han creat per al nou domini:

```bash
ls -la certs/alumni/
```

Hauries de veure `fullchain.pem` i `key.pem`.

---

## Pas 2: Desplegar la topologia de l'etapa 6

La topologia de l'etapa 6 afegeix el node `mail-alumni`. Atenció: aquest node és un contenidor Ubuntu que actua com a **placeholder** — el stack real de Mailcow es desplega via `docker compose` i es connecta a la xarxa del lab posteriorment.

```bash
./lab.sh deploy 6
```

Verifica que tots els nodes estan actius:

```bash
./lab.sh status
```

Hauries de veure 11 nodes: els 10 anteriors més `mail-alumni`.

> **Per què un placeholder?** Mailcow és un sistema multi-contenidor (~12 contenidors) que utilitza `docker-compose.yml` propi. Containerlab no pot gestionar directament stacks Docker Compose, de manera que s'utilitza un contenidor Ubuntu com a punt d'entrada de xarxa (amb IP `10.26.50.30`) i els contenidors de Mailcow es connecten a la mateixa xarxa.

---

## Pas 3: Executar el setup de l'etapa 6

```bash
./lab.sh setup 6
```

El setup configura els serveis de les etapes anteriors (DMS i Stalwart) i mostra instruccions per a la configuració manual de Mailcow. Mailcow requereix passos addicionals que es detallen a continuació.

---

## Pas 4: Configurar Mailcow amb generate_config.sh

Mailcow proporciona un script interactiu per generar la configuració inicial. Dins del directori de configuració de Mailcow:

### 4.1 Clonar o preparar Mailcow

Si Mailcow no està preconfigurat al directori `configs/mailcow/`, cal preparar-lo:

```bash
# Dins del directori de Mailcow
docker exec -it clab-mailserver-lab-mail-alumni bash
```

### 4.2 Generar la configuració

El fitxer `mailcow.conf` és el punt central de configuració de Mailcow. Els paràmetres clau són:

```bash
# Variables principals de mailcow.conf
MAILCOW_HOSTNAME=mail.alumni.demoasixcloud2025.cat
MAILCOW_PASS_SCHEME=BLF-CRYPT
DBNAME=mailcow
DBUSER=mailcow
DBPASS=<contrasenya_generada>
DBROOT=<contrasenya_root_generada>

# Ports
HTTP_PORT=8080
HTTPS_PORT=8443
SMTP_PORT=25
SMTPS_PORT=465
SUBMISSION_PORT=587
IMAP_PORT=143
IMAPS_PORT=993

# TLS
SSL_TYPE=manual
```

### 4.3 Iniciar el stack Mailcow

```bash
# Des del directori de Mailcow
docker compose up -d
```

Espera uns 3-5 minuts fins que tots els contenidors estiguin en estat `healthy`. Pots monitoritzar-ho amb:

```bash
docker compose ps
```

Hauries de veure aproximadament 12 contenidors:

| Contenidor | Funció |
|-----------|--------|
| `postfix-mailcow` | Servidor SMTP (MTA) |
| `dovecot-mailcow` | Servidor IMAP/POP3 (MDA) |
| `nginx-mailcow` | Proxy web (UI, SOGo) |
| `rspamd-mailcow` | Filtre anti-spam + DKIM |
| `mysql-mailcow` | MariaDB (base de dades) |
| `redis-mailcow` | Redis (cache, sessions) |
| `sogo-mailcow` | SOGo (webmail + calendari) |
| `php-fpm-mailcow` | PHP-FPM (admin interface) |
| `clamd-mailcow` | ClamAV (antivirus) |
| `unbound-mailcow` | DNS resolver local |
| `watchdog-mailcow` | Monitor de salut |
| `acme-mailcow` | Gestió automàtica de certificats |

---

## Pas 5: Accedir a la interfície web de Mailcow

Mailcow ofereix una interfície d'administració web molt completa. Accedeix-hi via el proxy:

```
http://mail.alumni.demoasixcloud2025.cat
```

O directament: `http://10.26.50.30:8080`

**Credencials d'administrador per defecte:**
- **Usuari:** `admin`
- **Contrasenya:** `moohoo` (canvia-la immediatament!)

La interfície de Mailcow ofereix:
- Dashboard amb estat dels serveis
- Gestió de dominis i bústies
- Configuració de DKIM (generació automàtica de claus)
- Registres (logs) en temps real
- Estadístiques de correu
- Configuració d'anti-spam (Rspamd)
- Polítiques de quarantena

---

## Pas 6: Crear el domini alumni a Mailcow

### 6.1 Afegir el domini

1. A la interfície web, navega a **Configuration → Mail Setup → Domains**
2. Fes clic a **Add domain**
3. **Domain:** `alumni.demoasixcloud2025.cat`
4. **Max. mailboxes:** 10
5. **Max. quota per mailbox (MB):** 1024
6. Fes clic a **Add domain and restart SOGo**

### 6.2 Generar claus DKIM per al domini

1. Navega a **Configuration → ARC/DKIM keys**
2. Selecciona el domini `alumni.demoasixcloud2025.cat`
3. **DKIM key length:** 2048
4. Fes clic a **Generate** (Generar)
5. Mailcow mostrarà el registre TXT que cal publicar al DNS

Copia el valor de la clau pública DKIM per al pas 8.

---

## Pas 7: Crear el compte d'exalumne

1. Navega a **Configuration → Mail Setup → Mailboxes**
2. Fes clic a **Add mailbox**
3. Completa el formulari:

| Camp | Valor |
|------|-------|
| **Username** | `exalumne1` |
| **Domain** | `alumni.demoasixcloud2025.cat` |
| **Full name** | `Exalumne 1` |
| **Password** | `Exalumne1.2025` |
| **Quota (MB)** | `256` |

4. Fes clic a **Add mailbox**

---

## Pas 8: Configurar DNS per al domini alumni a Cloudflare

Accedeix al panell de Cloudflare i crea els registres per al nou domini.

### 8.1 Registre MX

Verifica que existeix:

| Tipus | Nom | Contingut | Prioritat |
|-------|-----|-----------|-----------|
| MX | `alumni.demoasixcloud2025.cat` | `mail.alumni.demoasixcloud2025.cat` | 10 |

### 8.2 Registre SPF

| Tipus | Nom | Contingut |
|-------|-----|-----------|
| TXT | `alumni.demoasixcloud2025.cat` | `v=spf1 mx ~all` |

### 8.3 Registre DKIM

Utilitza la clau pública generada al pas 6.2:

| Tipus | Nom | Contingut |
|-------|-----|-----------|
| TXT | `dkim._domainkey.alumni.demoasixcloud2025.cat` | `v=DKIM1; k=rsa; p=...` (clau de Mailcow) |

> **Nota:** Mailcow usa el selector `dkim` per defecte, a diferència de DMS que usa `mail`. El selector és configurable.

### 8.4 Registre DMARC

| Tipus | Nom | Contingut |
|-------|-----|-----------|
| TXT | `_dmarc.alumni.demoasixcloud2025.cat` | `v=DMARC1; p=none; rua=mailto:postmaster@alumni.demoasixcloud2025.cat` |

### 8.5 Verificar els registres

```bash
dig @10.26.50.2 alumni.demoasixcloud2025.cat MX +short
dig @10.26.50.2 alumni.demoasixcloud2025.cat TXT +short
dig @10.26.50.2 dkim._domainkey.alumni.demoasixcloud2025.cat TXT +short
dig @10.26.50.2 _dmarc.alumni.demoasixcloud2025.cat TXT +short
```

---

## Pas 9: Provar l'enviament amb SOGo

SOGo és el client webmail integrat de Mailcow. A diferència de Roundcube (que es desplega per separat), SOGo forma part del stack de Mailcow i ofereix funcionalitats addicionals com calendari i contactes (GroupDAV/CardDAV).

### 9.1 Accedir a SOGo

```
http://mail.alumni.demoasixcloud2025.cat/SOGo
```

**Credencials:**
- **Usuari:** `exalumne1@alumni.demoasixcloud2025.cat`
- **Contrasenya:** `Exalumne1.2025`

### 9.2 Enviar un correu de prova

1. Fes clic a **Mail** (icona de sobre)
2. Fes clic a **Write** (Redactar)
3. **To:** `exalumne1@alumni.demoasixcloud2025.cat` (a si mateix, com a prova)
4. **Subject:** `Prova SOGo etapa 6`
5. **Cos:** `Aquest correu s'envia des de SOGo, el webmail integrat de Mailcow.`
6. Fes clic a **Send**

### 9.3 Verificar la recepció

Refresca la bústia d'entrada. Hauries de veure el missatge amb les capçaleres DKIM i SPF correctes.

### 9.4 Comparar SOGo amb Roundcube

| Funcionalitat | SOGo | Roundcube |
|--------------|------|-----------|
| **Webmail** | Sí | Sí |
| **Calendari** | Sí (CalDAV) | No (cal plugins) |
| **Contactes** | Sí (CardDAV) | Sí (bàsic) |
| **ActiveSync** | Sí | No |
| **Integració servidor** | Dins Mailcow | Independent |
| **Sincronització mòbil** | Sí (via ActiveSync) | No |

---

## Pas 10: Comparativa final dels tres servidors de correu

Aquesta és la comparativa completa que sintetitza tot el que hem après al llarg del laboratori.

### 10.1 Taula comparativa general

| Característica | docker-mailserver (DMS) | Stalwart | Mailcow |
|---------------|------------------------|----------|---------|
| **Filosofia** | Unix toolkit empaquetat | Servidor monolític modern | Plataforma completa |
| **Llenguatge** | C (Postfix/Dovecot) + Bash | Rust | C (Postfix/Dovecot) + PHP |
| **Contenidors** | 1 | 1 | ~12 |
| **MTA (SMTP)** | Postfix | Integrat (Rust) | Postfix |
| **MDA (IMAP)** | Dovecot | Integrat (Rust) | Dovecot |
| **Anti-spam** | Rspamd o SpamAssassin | Integrat (sieve) | Rspamd |
| **Antivirus** | ClamAV (opcional) | No inclòs | ClamAV |
| **Webmail** | Cap (extern) | Cap (extern) | SOGo (integrat) |
| **Base de dades** | Fitxers plans (Maildir) | RocksDB | MariaDB + Maildir |
| **Cache** | Cap | Cap | Redis |
| **Admin UI** | Cap (CLI) | Web UI + API REST | Web UI completa |
| **Configuració** | Variables d'entorn | config.toml + API | mailcow.conf + Web |
| **DKIM** | Via Rspamd/OpenDKIM | Natiu | Via Rspamd |
| **Protocols** | SMTP, IMAP, POP3 | SMTP, IMAP, POP3, JMAP | SMTP, IMAP, POP3 |
| **ACME (certs)** | Manual | Integrat (opcional) | Integrat |
| **RAM mínima** | ~512 MB | ~256 MB | ~4 GB |
| **Dificultat** | Mitjana | Baixa-Mitjana | Alta (setup), Baixa (ús) |

### 10.2 Quan escollir cada servidor

| Escenari | Servidor recomanat | Raó |
|----------|-------------------|-----|
| Servidor personal o petit equip | Stalwart | Lleuger, fàcil de configurar, un sol binari |
| Empresa mitjana amb equip tècnic | DMS | Flexible, personalitzable, components Unix provats |
| Organització gran amb admin no tècnic | Mailcow | UI completa, calendari/contactes, gestió visual |
| Entorn amb recursos limitats | Stalwart | Mínim consum de RAM i CPU |
| Necessitat de JMAP/protocols moderns | Stalwart | Únic amb suport JMAP natiu |
| Necessitat d'antivirus integrat | Mailcow o DMS | ClamAV integrat |
| Migració des de Exchange/Office365 | Mailcow | ActiveSync via SOGo |

---

## Resum de l'Etapa 6

| Node | IP | Servei | Contenidors |
|------|----|--------|-------------|
| `mail-alumnat` | 10.26.50.10 | docker-mailserver | 1 |
| `mail-professorat` | 10.26.50.20 | Stalwart | 1 |
| `mail-alumni` | 10.26.50.30 | Mailcow | ~12 |

| Accés | URL |
|-------|-----|
| Mailcow Admin | `http://mail.alumni.demoasixcloud2025.cat` |
| SOGo Webmail | `http://mail.alumni.demoasixcloud2025.cat/SOGo` |
| Roundcube | `http://localhost:8081` |
| Thunderbird 1 | `http://localhost:5800` |
| Thunderbird 2 | `http://localhost:5801` |
| Stalwart Admin | `http://admin.professorat.demoasixcloud2025.cat` |

| Comptes al lab | Servidor | Contrasenya |
|----------------|----------|-------------|
| `alumne1@alumnat.(...)` | DMS | `Alumne1.2025` |
| `alumne2@alumnat.(...)` | DMS | `Alumne2.2025` |
| `profe1@professorat.(...)` | Stalwart | `Profe1.2025` |
| `profe2@professorat.(...)` | Stalwart | `Profe2.2025` |
| `exalumne1@alumni.(...)` | Mailcow | `Exalumne1.2025` |

---

## Observacions importants

1. **Mailcow és el servidor més complex del laboratori.** La seva arquitectura multi-contenidor (microserveis) ofereix modularitat i escalabilitat, però a costa d'una major complexitat operacional i consum de recursos.

2. **El placeholder Ubuntu a Containerlab** és una solució pragmàtica. Containerlab gestiona contenidors individuals, no stacks Docker Compose. El contenidor Ubuntu proporciona la interfície de xarxa (`eth1` amb IP `10.26.50.30`) i els contenidors de Mailcow es connecten a la mateixa xarxa.

3. **MariaDB vs RocksDB vs fitxers plans:** Cada servidor usa una estratègia d'emmagatzematge diferent. MariaDB (Mailcow) és la més robusta per a consultes complexes; RocksDB (Stalwart) és la més eficient per a escriptures; Maildir (DMS) és la més transparent i fàcil de fer backups.

4. **Redis a Mailcow** s'usa per a cache de sessions, limitació de velocitat (rate limiting) i cues. No emmagatzema correus — això ho fa Dovecot amb Maildir sobre el sistema de fitxers.

5. **ClamAV consumeix molta RAM** (~1-2 GB per si sol). En entorns amb recursos limitats, considera desactivar-lo tant a DMS com a Mailcow.

6. **SOGo ofereix ActiveSync**, que permet sincronitzar correu, calendari i contactes amb dispositius mòbils (iOS, Android) sense necessitat d'aplicacions de tercers. Aquesta és una funcionalitat única de Mailcow en el nostre laboratori.

7. **Els tres servidors comparteixen la mateixa xarxa** (`10.26.50.0/24`) però els dominis estan aïllats per disseny. En un entorn de producció, caldria configurar les relacions de confiança entre servidors per permetre l'enviament entre dominis.

---

## Preguntes de reflexió — Etapa 6

1. Per quina raó Mailcow utilitza múltiples contenidors (microserveis) en lloc d'un sol contenidor com DMS o Stalwart? Quins avantatges i inconvenients té l'arquitectura de microserveis per a un servidor de correu? Pensa en actualitzacions independents, aïllament de fallades i complexitat operacional.

2. Compara el nombre de contenidors de cada servidor: DMS (1), Stalwart (1), Mailcow (~12). Quina relació hi ha entre el nombre de contenidors i la facilitat d'administració, el consum de recursos i la resiliència? Un servidor amb més contenidors és necessàriament millor?

3. Què ofereix SOGo que Roundcube no té? Compara ambdós clients webmail en termes de funcionalitats (calendari, contactes, ActiveSync), integració amb el servidor i experiència d'usuari. En quins escenaris triaries Roundcube per sobre de SOGo?

4. Com s'utilitza MariaDB a Mailcow i en què es diferencia de RocksDB (Stalwart)? Compara una base de dades relacional (SQL) amb una base de dades clau-valor (LSM-tree) per a l'emmagatzematge de metadades de correu electrònic. Quines consultes són més eficients en cadascuna?

5. Rspamd apareix tant a DMS com a Mailcow. Quin paper juga en cada cas? Com es configura a DMS (variables d'entorn) vs Mailcow (interfície web)? Quins avantatges té la configuració visual de Rspamd a Mailcow per a un administrador no tècnic?

6. Quins reptes específics planteja el desplegament de Mailcow dins de Containerlab? Per què cal un contenidor placeholder? Com es podria millorar la integració entre Containerlab i Docker Compose? Existeixen alternatives a aquest enfocament?

7. Imagina que has de recomanar un servidor de correu per a tres escenaris: (a) un freelance que vol el seu propi domini de correu, (b) una pime de 50 empleats, (c) una universitat amb 10.000 estudiants. Quin triaries per a cada cas i per quina raó?

8. Què orquestra el fitxer `docker-compose.yml` de Mailcow? Descriu com Docker Compose gestiona les dependències entre contenidors (per exemple, Postfix necessita que MariaDB estigui llest abans d'arrancar). Com es compara això amb el model de DMS on `supervisord` gestiona processos dins d'un sol contenidor?

9. Com gestiona Mailcow els certificats TLS en comparació amb la gestió manual de certificats a DMS i Stalwart? Mailcow inclou el seu propi client ACME. Quins avantatges i riscos comporta la gestió automàtica de certificats dins del stack?

10. Cap on evoluciona el correu electrònic? Compara JMAP (suportat per Stalwart) amb IMAP (usat per DMS i Mailcow). Creus que JMAP substituirà IMAP a llarg termini? Com afecten les tendències de consolidació (Gmail, Outlook 365) al futur dels servidors de correu autogestionats?
