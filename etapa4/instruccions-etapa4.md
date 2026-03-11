# Laboratori de Servidors de Correu — Etapa 4: Seguretat del correu amb DKIM, DMARC i SPF

## Objectiu

Configurar els tres mecanismes fonamentals d'autenticació i seguretat del correu electrònic — **SPF**, **DKIM** i **DMARC** — per al domini `alumnat.demoasixcloud2025.cat`. Es generaran les claus criptogràfiques DKIM al servidor docker-mailserver (amb Rspamd), es publicaran els registres DNS corresponents a Cloudflare, i es verificarà el correcte funcionament de tot el sistema de signatura i validació de missatges.

Aquesta etapa no afegeix cap node nou a la topologia. Tots els canvis són de configuració: s'activa **Rspamd** com a motor de signatura DKIM (en substitució d'OpenDKIM/OpenDMARC) i es publiquen registres TXT al DNS.

---

## Arquitectura de la xarxa

```
Host Linux (tu)
  │
  ├─ http://localhost:8080  → Proxy Nginx (índex serveis)
  └─ http://localhost:5800  → Thunderbird 1 (noVNC)

  Xarxa LAN: 10.26.50.0/24
  ┌─────────────────────────────────────────────────────────────────────┐
  │                                                                     │
  │  [switch-lan]           Linux bridge (switch L2)                    │
  │       │                                                             │
  │       ├── [router-frr]     10.26.50.1   Gateway (FRRouting)         │
  │       ├── [coredns]        10.26.50.2   DNS intern                  │
  │       ├── [proxy]          10.26.50.3   Nginx reverse proxy         │
  │       ├── [mail-alumnat]   10.26.50.10  DMS + Rspamd (DKIM/SPF)    │
  │       ├── [thunderbird1]   10.26.50.100 Client de correu (noVNC)    │
  │       ├── [acme]           10.26.50.250 Certificats Let's Encrypt   │
  │       └── [client-swaks]   10.26.50.200 Client CLI (swaks)          │
  │                                                                     │
  └─────────────────────────────────────────────────────────────────────┘

  Flux de signatura DKIM (enviament):
    mail-alumnat (Rspamd) → signa amb clau privada → afegeix capçalera DKIM-Signature

  Flux de verificació (recepció):
    Servidor receptor → consulta DNS TXT (mail._domainkey) → obté clau pública → verifica signatura

  Registres DNS nous (Cloudflare):
    alumnat.demoasixcloud2025.cat          TXT  "v=spf1 mx ~all"
    mail._domainkey.alumnat.(...)          TXT  "v=DKIM1; k=rsa; p=..."
    _dmarc.alumnat.demoasixcloud2025.cat   TXT  "v=DMARC1; p=none; rua=..."
```

---

## Prerequisits

- Etapes 1, 2 i 3 completades correctament
- Certificats TLS vàlids per a `alumnat.demoasixcloud2025.cat` (generats a l'etapa 2)
- Accés al panell de Cloudflare per gestionar els registres DNS del domini
- Familiaritat bàsica amb criptografia de clau pública (clau privada / clau pública)
- Eina `dig` disponible al sistema host o dins dels contenidors

---

## Pas 1: Desplegar la topologia de l'etapa 4

La topologia de l'etapa 4 és idèntica a l'etapa 3, amb un canvi clau: el node `mail-alumnat` ara té la variable d'entorn `ENABLE_RSPAMD=1` (i `ENABLE_OPENDKIM=0`, `ENABLE_OPENDMARC=0`). Rspamd substitueix OpenDKIM i OpenDMARC com a motor integrat de signatura i verificació.

```bash
./lab.sh deploy 4
```

Verifica que tots els nodes estan actius:

```bash
./lab.sh status
```

Hauries de veure 7 nodes: `switch-lan`, `router-frr`, `coredns`, `proxy`, `mail-alumnat`, `thunderbird1`, `acme` i `client-swaks`.

---

## Pas 2: Executar el setup (generació de claus DKIM)

L'script de setup de l'etapa 4 crea els comptes d'usuari i, a més, genera les claus DKIM per al domini `alumnat.demoasixcloud2025.cat`:

```bash
./lab.sh setup 4
```

Internament, el setup executa `setup config dkim keysize 2048 domain alumnat.demoasixcloud2025.cat` dins del contenidor DMS. Això genera un parell de claus RSA de 2048 bits:
- **Clau privada:** la utilitza Rspamd per signar els missatges sortints
- **Clau pública:** cal publicar-la al DNS perquè els receptors puguin verificar la signatura

---

## Pas 3: Verificar les claus DKIM generades

Comprova que les claus s'han creat correctament dins del contenidor:

```bash
docker exec clab-mailserver-lab-mail-alumnat \
    ls -la /tmp/docker-mailserver/opendkim/keys/alumnat.demoasixcloud2025.cat/
```

Hauries de veure almenys dos fitxers:
- `mail.txt` — el registre DNS amb la clau pública (en format BIND)
- `mail.private` — la clau privada RSA (mai s'ha de compartir)

---

## Pas 4: Obtenir el registre DNS DKIM

Mostra el contingut del fitxer `mail.txt` per obtenir el registre TXT que cal publicar al DNS:

```bash
docker exec clab-mailserver-lab-mail-alumnat \
    cat /tmp/docker-mailserver/opendkim/keys/alumnat.demoasixcloud2025.cat/mail.txt
```

La sortida tindrà un format semblant a:

```
mail._domainkey IN  TXT ( "v=DKIM1; h=sha256; k=rsa; "
    "p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA..."
    "... clau pública en base64 ..." )
```

**Important:** Copia tot el valor de la clau pública (el camp `p=`). Si el text està dividit en múltiples línies amb cometes, cal concatenar-lo tot en una sola cadena sense espais ni salts de línia.

---

## Pas 5: Configurar el registre SPF a Cloudflare

SPF (Sender Policy Framework) defineix quins servidors estan autoritzats a enviar correu en nom del domini.

Accedeix al panell de Cloudflare i crea el registre:

| Camp | Valor |
|------|-------|
| **Tipus** | TXT |
| **Nom** | `alumnat.demoasixcloud2025.cat` |
| **Contingut** | `v=spf1 mx ~all` |
| **TTL** | Auto |

**Explicació del registre:**
- `v=spf1` — versió del protocol SPF
- `mx` — autoritza els servidors definits als registres MX del domini
- `~all` — *softfail*: els correus des de servidors no autoritzats es marquen com a sospitosos (però no es rebutgen)

> **Nota:** En producció, s'usaria `-all` (hardfail) per rebutjar directament els correus no autoritzats. S'usa `~all` durant les proves per evitar pèrdues accidentals de missatges.

---

## Pas 6: Configurar el registre DKIM a Cloudflare

DKIM (DomainKeys Identified Mail) permet al servidor de correu signar digitalment els missatges. El receptor comprova la signatura consultant la clau pública publicada al DNS.

Crea el registre a Cloudflare:

| Camp | Valor |
|------|-------|
| **Tipus** | TXT |
| **Nom** | `mail._domainkey.alumnat.demoasixcloud2025.cat` |
| **Contingut** | `v=DKIM1; h=sha256; k=rsa; p=MIIBIjAN...` (la clau del pas 4) |
| **TTL** | Auto |

**Punts importants:**
- El **selector** és `mail` (el prefix de `mail._domainkey`). Cada servidor pot tenir un selector diferent.
- La clau pública (`p=`) s'ha de posar sencera, en una sola línia, sense espais ni cometes internes.
- No incloguis els parèntesis ni les cometes del format BIND — només el contingut textual.

---

## Pas 7: Configurar el registre DMARC a Cloudflare

DMARC (Domain-based Message Authentication, Reporting & Conformance) indica als servidors receptors què han de fer quan un missatge falla les verificacions SPF i/o DKIM.

Crea el registre a Cloudflare:

| Camp | Valor |
|------|-------|
| **Tipus** | TXT |
| **Nom** | `_dmarc.alumnat.demoasixcloud2025.cat` |
| **Contingut** | `v=DMARC1; p=none; rua=mailto:postmaster@alumnat.demoasixcloud2025.cat` |
| **TTL** | Auto |

**Explicació dels camps:**
- `v=DMARC1` — versió del protocol DMARC
- `p=none` — política: no fer res especial amb els correus que fallen (mode monitorització)
- `rua=mailto:...` — adreça on rebre informes agregats diaris sobre autenticació

> **Les tres polítiques DMARC:**
> - `p=none` — només monitoritza (recomanat inicialment)
> - `p=quarantine` — envia els correus que fallen a la carpeta de spam
> - `p=reject` — rebutja directament els correus que fallen (màxima seguretat)

---

## Pas 8: Verificar els registres DNS amb dig

Comprova que els tres registres s'han propagat correctament. Podem consultar tant el DNS intern (CoreDNS) com directament Cloudflare:

### 8.1 Verificar SPF

```bash
dig @10.26.50.2 alumnat.demoasixcloud2025.cat TXT +short
```

Sortida esperada:
```
"v=spf1 mx ~all"
```

### 8.2 Verificar DKIM

```bash
dig @10.26.50.2 mail._domainkey.alumnat.demoasixcloud2025.cat TXT +short
```

Sortida esperada:
```
"v=DKIM1; h=sha256; k=rsa; p=MIIBIjAN..."
```

### 8.3 Verificar DMARC

```bash
dig @10.26.50.2 _dmarc.alumnat.demoasixcloud2025.cat TXT +short
```

Sortida esperada:
```
"v=DMARC1; p=none; rua=mailto:postmaster@alumnat.demoasixcloud2025.cat"
```

> **Nota:** Si els registres es consulten al DNS públic de Cloudflare (`dig @1.1.1.1 ...`), cal esperar uns minuts per a la propagació. Al DNS intern (CoreDNS), els registres s'actualitzen immediatament si s'han afegit a la zona local.

---

## Pas 9: Enviar un correu amb swaks i verificar la signatura DKIM

Utilitza el client swaks per enviar un correu de prova i comprovar que Rspamd afegeix la capçalera `DKIM-Signature`:

```bash
docker exec clab-mailserver-lab-client-swaks \
    swaks \
    --to alumne1@alumnat.demoasixcloud2025.cat \
    --from alumne2@alumnat.demoasixcloud2025.cat \
    --server 10.26.50.10 \
    --port 587 \
    --auth LOGIN \
    --auth-user alumne2@alumnat.demoasixcloud2025.cat \
    --auth-password 'Alumne2.2025' \
    --tls \
    --header "Subject: Prova DKIM etapa 4" \
    --body "Aquest correu hauria de tenir signatura DKIM."
```

A la sortida de swaks, fixa't en el codi de resposta: ha de ser `250 2.0.0 Ok: queued`.

---

## Pas 10: Analitzar les capçaleres del correu rebut

Accedeix a Thunderbird (http://localhost:5800) amb el compte `alumne1@alumnat.demoasixcloud2025.cat` i obre el missatge rebut. Visualitza les capçaleres completes del missatge (View → Message Source o Ctrl+U).

Cerca les capçaleres clau:

### 10.1 Capçalera DKIM-Signature

```
DKIM-Signature: v=1; a=rsa-sha256; c=relaxed/relaxed;
    d=alumnat.demoasixcloud2025.cat; s=mail;
    h=from:to:subject:date:message-id;
    bh=...; b=...
```

**Camps rellevants:**
- `a=rsa-sha256` — algorisme de signatura
- `d=` — domini que signa
- `s=mail` — selector DKIM
- `h=` — capçaleres incloses a la signatura
- `b=` — la signatura digital en base64

### 10.2 Capçalera Authentication-Results

```
Authentication-Results: mail.alumnat.demoasixcloud2025.cat;
    dkim=pass header.d=alumnat.demoasixcloud2025.cat;
    spf=pass smtp.mailfrom=alumne2@alumnat.demoasixcloud2025.cat;
    dmarc=pass header.from=alumnat.demoasixcloud2025.cat
```

Cada mecanisme mostra `pass` o `fail`:
- `dkim=pass` — la signatura DKIM és vàlida
- `spf=pass` — el servidor emissor està autoritzat per SPF
- `dmarc=pass` — tant DKIM com SPF passen i estan alineats amb el domini `From`

---

## Resum de l'Etapa 4

| Element | Registre DNS | Tipus | Funció |
|---------|-------------|-------|--------|
| **SPF** | `alumnat.demoasixcloud2025.cat` | TXT | Defineix quins servidors poden enviar correu pel domini |
| **DKIM** | `mail._domainkey.alumnat.(...)` | TXT | Publica la clau pública per verificar signatures digitals |
| **DMARC** | `_dmarc.alumnat.(...)` | TXT | Indica als receptors la política quan SPF/DKIM fallen |

| Comanda de verificació | Què comprova |
|----------------------|--------------|
| `dig @10.26.50.2 alumnat.(...) TXT` | Registre SPF publicat |
| `dig @10.26.50.2 mail._domainkey.alumnat.(...) TXT` | Clau pública DKIM |
| `dig @10.26.50.2 _dmarc.alumnat.(...) TXT` | Política DMARC |
| `swaks --to ... --server 10.26.50.10 --tls` | Enviament amb signatura DKIM |
| Thunderbird → View Source | Capçaleres Authentication-Results |

| Variable DMS | Valor | Efecte |
|-------------|-------|--------|
| `ENABLE_RSPAMD` | `1` | Activa Rspamd (signatura DKIM, verificació SPF/DMARC) |
| `ENABLE_OPENDKIM` | `0` | Desactiva OpenDKIM (substituït per Rspamd) |
| `ENABLE_OPENDMARC` | `0` | Desactiva OpenDMARC (substituït per Rspamd) |
| `ENABLE_POLICYD_SPF` | `0` | Desactiva policyd-spf (substituït per Rspamd) |

---

## Observacions importants

1. **SPF, DKIM i DMARC són complementaris**, no alternatives. SPF verifica el servidor emissor, DKIM verifica la integritat del missatge, i DMARC unifica les dues verificacions sota una política de domini.

2. **Rspamd substitueix tres eines separades** (OpenDKIM, OpenDMARC, policyd-spf) en un sol motor integrat. Això simplifica la configuració però centralitza la complexitat.

3. **La clau privada DKIM mai s'ha de compartir.** Resideix únicament dins del servidor de correu. Si es compromet, cal generar un nou parell de claus i actualitzar el registre DNS.

4. **El selector DKIM** (`mail` en aquest cas) permet rotar claus sense interrupció: es crea un nou selector, es publica al DNS, i es retira l'antic després d'un període de transició.

5. **`p=none` és imprescindible en fase de proves.** Canviar directament a `p=reject` sense monitorització prèvia pot provocar que correus legítims siguin rebutjats per configuracions incorrectes.

6. **SPF i reenviament:** SPF pot fallar quan un correu es reenvia, perquè el servidor intermedi no està al registre SPF del domini original. DKIM sobreviu al reenviament perquè la signatura viatja amb el missatge.

7. **Els informes DMARC (`rua=`)** són molt útils en producció. Serveis com Google i Yahoo envien informes XML diaris que permeten detectar intents de suplantació (spoofing) del domini.

---

## Preguntes de reflexi -- Etapa 4

1. Què és SPF i com funciona? Descriu el procés complet des que un servidor receptor rep un correu fins que consulta el registre SPF del domini emissor. Quina diferència hi ha entre `~all` (softfail) i `-all` (hardfail)?

2. Què és DKIM i com funciona el mecanisme de signatura? Explica el paper de la clau privada (al servidor emissor) i la clau pública (al DNS). Per què s'usa criptografia asimètrica en lloc de simètrica?

3. Què és DMARC i quines són les tres polítiques disponibles (`none`, `quarantine`, `reject`)? En quin ordre recomanaries implementar-les en un domini nou i per quina raó?

4. Què és el selector DKIM (en el nostre cas, `mail` a `mail._domainkey`)? Quina utilitat té poder tenir múltiples selectors per a un mateix domini? Dona un exemple pràctic de rotació de claus.

5. Com s'interpreten les capçaleres `Authentication-Results`? Si un correu mostra `dkim=fail` però `spf=pass`, què significa i com actuaria un servidor amb política DMARC `p=quarantine`?

6. Què passa quan un correu legítim falla la verificació SPF? Descriu un escenari realista (per exemple, reenviament de correu) i com DKIM pot compensar aquesta fallada.

7. Què signifiquen els camps `rua=` i `ruf=` a un registre DMARC? Quina diferència hi ha entre informes agregats (aggregate) i informes forenses (forensic)? Per què `ruf=` s'usa menys en producció?

8. Per quina raó és perillós configurar `p=reject` directament sense haver passat per `p=none`? Descriu un escenari on correus legítims podrien ser rebutjats injustament.

9. Com sobreviu la signatura DKIM al reenviament de correu? Explica per què la capçalera `DKIM-Signature` es manté intacta quan un servidor reenvia el missatge, però SPF falla en el mateix escenari.

10. Descriu la relació entre SPF, DKIM i DMARC com a sistema de seguretat per capes. Per què cap d'aquests mecanismes és suficient per si sol? Quines amenaces específiques cobreix cadascun (spoofing del sobre, manipulació del cos, suplantació del domini `From`)?
