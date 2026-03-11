# Laboratori de Servidors de Correu — Etapa 3: Enviament d'emails via terminal amb swaks

## Objectiu

Utilitzar **swaks** (Swiss Army Knife for SMTP) per enviar i depurar correus electrònics des de la línia de comandes. L'alumnat aprendrà a interactuar directament amb el protocol SMTP, entendre cada pas de la transacció (EHLO, MAIL FROM, RCPT TO, DATA, QUIT), diferenciar entre els modes d'enviament (port 25, 587 amb STARTTLS, 465 amb TLS implícit) i analitzar el tràfic generat. Això proporciona una comprensió profunda del protocol SMTP que no s'obté amb un client gràfic.

---

## Arquitectura de la xarxa

```
Host Linux (tu)
  |
  +-- http://localhost:8080   --> Proxy Nginx (accés als serveis web)
  +-- http://localhost:5800   --> Thunderbird GUI (noVNC)

  Xarxa LAN: 10.26.50.0/24
  +------------------------------------------------------------------+
  |                                                                  |
  |  [switch-lan]              Linux bridge (L2)                     |
  |       |                                                          |
  |       +---- [router-frr]    10.26.50.1   Gateway / FRR           |
  |       |                                                          |
  |       +---- [coredns]       10.26.50.2   DNS intern              |
  |       |                                                          |
  |       +---- [proxy]         10.26.50.3   Nginx proxy invers      |
  |       |                                                          |
  |       +---- [mail-alumnat]  10.26.50.10  docker-mailserver       |
  |       |                     Postfix (SMTP) + Dovecot (IMAP)      |
  |       |                     Ports: 25, 465, 587, 993             |
  |       |                                                          |
  |       +---- [thunderbird1]  10.26.50.100 Client de correu        |
  |       |                                                          |
  |       +---- [acme]          10.26.50.250 Client ACME             |
  |       |                                                          |
  |       +---- [client-swaks]  10.26.50.200 Client SMTP (swaks)     |
  |                              Eina de línia de comandes            |
  |                                                                  |
  +------------------------------------------------------------------+

  Flux d'un correu via swaks:

  [client-swaks] --SMTP--> [mail-alumnat] --entrega--> bústia alumne1
   10.26.50.200    port 25/587/465  10.26.50.10       /var/mail/...
```

**Node nou:** `client-swaks` (10.26.50.200) — contenidor amb `swaks`, `dig`, `curl` i altres eines de diagnòstic.

---

## Prerequisits

### Al host Linux

```bash
# 1. Etapa 2 completada (certificats TLS generats i disponibles a certs/alumnat/)
# 2. Fitxer .env configurat amb les credencials de Cloudflare
# 3. Imatges Docker construïdes (inclosa mail-client-swaks)
```

Verifica que les imatges necessàries existeixen:

```bash
docker images | grep -E "mail-switch|mail-client-swaks|mail-acme"
```

Si no existeixen, construeix-les:

```bash
./lab.sh build
```

---

## Pas 1: Desplegar el laboratori (Etapa 3)

```bash
./lab.sh deploy 3
```

Comprova que els contenidors estan actius:

```bash
./lab.sh status
```

Hauries de veure 7 nodes: `switch-lan`, `router-frr`, `coredns`, `proxy`, `mail-alumnat`, `thunderbird1`, `acme`, i el nou node `client-swaks`.

---

## Pas 2: Configurar els comptes de correu

```bash
./lab.sh setup 3
```

Això crea els comptes `alumne1` i `alumne2` al servidor docker-mailserver.

---

## Pas 3: Accedir al client swaks

```bash
./lab.sh shell client-swaks
```

Un cop dins del contenidor, verifica que `swaks` està instal·lat:

```bash
swaks --version
```

Verifica la connectivitat amb el servidor de correu:

```bash
# Ping al servidor
ping -c 3 10.26.50.10

# Verificar que el port 25 està obert
nc -zv 10.26.50.10 25
```

---

## Pas 4: Enviament bàsic sense autenticació (port 25)

El port 25 és el port estàndard per a la comunicació SMTP entre servidors. En aquest laboratori, DMS accepta connexions al port 25 des de la xarxa interna sense requerir autenticació (gràcies a la configuració `PERMIT_DOCKER: network`).

```bash
swaks \
  --to alumne1@alumnat.demoasixcloud2025.cat \
  --from alumne2@alumnat.demoasixcloud2025.cat \
  --server 10.26.50.10 \
  --port 25
```

### Interpretar la sortida de swaks

```
=== Trying 10.26.50.10:25...
=== Connected to 10.26.50.10.
<-  220 mail.alumnat.demoasixcloud2025.cat ESMTP
 -> EHLO client-swaks
<-  250-mail.alumnat.demoasixcloud2025.cat
<-  250-PIPELINING
<-  250-SIZE 10240000
<-  250-STARTTLS
<-  250 8BITMIME
 -> MAIL FROM:<alumne2@alumnat.demoasixcloud2025.cat>
<-  250 2.1.0 Ok
 -> RCPT TO:<alumne1@alumnat.demoasixcloud2025.cat>
<-  250 2.1.5 Ok
 -> DATA
<-  354 End data with <CR><LF>.<CR><LF>
 -> [cos del missatge]
 -> .
<-  250 2.0.0 Ok: queued as XXXXXXX
 -> QUIT
<-  221 2.0.0 Bye
```

**Explicació de cada pas:**
1. **Connexió TCP** al port 25 del servidor
2. **220**: Salutació del servidor (banner SMTP)
3. **EHLO**: El client s'identifica i demana les capacitats del servidor
4. **250**: El servidor llista les seves extensions (PIPELINING, STARTTLS, etc.)
5. **MAIL FROM**: El client indica l'adreça del remitent (sobre/envelope)
6. **RCPT TO**: El client indica el destinatari
7. **DATA**: El client envia el cos del missatge, acabant amb un punt sol en una línia
8. **QUIT**: El client tanca la connexió

> **Nota:** Amb `<-` swaks indica les respostes del servidor, i amb `->` les comandes enviades.

---

## Pas 5: Enviament amb autenticació i STARTTLS (port 587)

El port 587 és el port de **submissió** (submission). Requereix autenticació i STARTTLS:

```bash
swaks \
  --to alumne1@alumnat.demoasixcloud2025.cat \
  --from alumne2@alumnat.demoasixcloud2025.cat \
  --server 10.26.50.10 \
  --port 587 \
  --auth LOGIN \
  --auth-user alumne2@alumnat.demoasixcloud2025.cat \
  --auth-password 'Alumne2.2025' \
  --tls
```

**Opcions clau:**
- `--port 587`: Port de submissió
- `--auth LOGIN`: Mecanisme d'autenticació
- `--auth-user` / `--auth-password`: Credencials de l'usuari
- `--tls`: Activa STARTTLS (actualitza la connexió a TLS abans d'autenticar-se)

### Diferència amb el port 25

A la sortida de swaks, observaràs un pas addicional:

```
 -> STARTTLS
<-  220 2.0.0 Ready to start TLS
=== TLS started with cipher TLS_AES_256_GCM_SHA384
 -> EHLO client-swaks
...
 -> AUTH LOGIN
<-  334 VXNlcm5hbWU6
 -> [usuari codificat en base64]
<-  334 UGFzc3dvcmQ6
 -> [contrasenya codificada en base64]
<-  235 2.7.0 Authentication successful
```

> **Important:** Amb STARTTLS, la connexió comença en text pla i s'actualitza a TLS
> **abans** d'enviar les credencials. Això protegeix l'autenticació.

---

## Pas 6: Enviament amb TLS implícit (port 465)

El port 465 utilitza **TLS implícit** (SMTPS): la connexió TLS s'estableix immediatament:

```bash
swaks \
  --to alumne1@alumnat.demoasixcloud2025.cat \
  --from alumne2@alumnat.demoasixcloud2025.cat \
  --server 10.26.50.10 \
  --port 465 \
  --tlsc \
  --auth LOGIN \
  --auth-user alumne2@alumnat.demoasixcloud2025.cat \
  --auth-password 'Alumne2.2025'
```

**Opcions clau:**
- `--port 465`: Port SMTPS (TLS implícit)
- `--tlsc`: Activa TLS implícit des de l'inici (no STARTTLS)
- `--auth LOGIN`: Autenticació LOGIN

### Comparació dels tres modes

| Aspecte | Port 25 | Port 587 | Port 465 |
|---------|---------|----------|----------|
| Ús principal | Entre servidors (relay) | Submissió clients | Submissió clients |
| TLS | Opcional (STARTTLS) | Obligatori (STARTTLS) | Implícit des de l'inici |
| Autenticació | No requerida (relay) | Obligatòria | Obligatòria |
| Opció swaks | (cap) | `--tls` | `--tlsc` |

---

## Pas 7: Personalitzar l'assumpte i el cos del correu

Swaks permet personalitzar completament el missatge:

### 7.1 Assumpte i cos simple

```bash
swaks \
  --to alumne1@alumnat.demoasixcloud2025.cat \
  --from alumne2@alumnat.demoasixcloud2025.cat \
  --server 10.26.50.10 \
  --port 465 \
  --tlsc \
  --auth LOGIN \
  --auth-user alumne2@alumnat.demoasixcloud2025.cat \
  --auth-password 'Alumne2.2025' \
  --header "Subject: Test des de terminal" \
  --body "Hola des de swaks! Aquest correu ha estat enviat des de la línia de comandes."
```

### 7.2 Capçaleres personalitzades

```bash
swaks \
  --to alumne1@alumnat.demoasixcloud2025.cat \
  --from alumne2@alumnat.demoasixcloud2025.cat \
  --server 10.26.50.10 \
  --port 465 \
  --tlsc \
  --auth LOGIN \
  --auth-user alumne2@alumnat.demoasixcloud2025.cat \
  --auth-password 'Alumne2.2025' \
  --header "Subject: Correu amb capçaleres personalitzades" \
  --header "X-Lab-Etapa: 3" \
  --header "X-Enviament: Terminal-swaks" \
  --body "Cos del missatge amb capçaleres addicionals."
```

### 7.3 Verificar la recepció a Thunderbird

Obre Thunderbird (http://localhost:5800), accedeix al compte d'alumne1 i verifica que els correus enviats amb swaks han arribat correctament. Comprova les capçaleres completes del missatge (**View > Message Source** o `Ctrl+U`).

---

## Pas 8: Verificar els registres DNS

Des del contenidor `client-swaks`, utilitza `dig` per consultar els registres DNS relacionats amb el correu:

### 8.1 Registre MX (Mail Exchanger)

```bash
dig @10.26.50.2 alumnat.demoasixcloud2025.cat MX
```

**Resultat esperat:**

```
;; ANSWER SECTION:
alumnat.demoasixcloud2025.cat. 3600 IN MX 10 mail.alumnat.demoasixcloud2025.cat.
```

El número `10` és la **prioritat**: un valor més baix indica preferència. Si hi hagués múltiples registres MX, el servidor amb la prioritat més baixa rebria els correus primer.

### 8.2 Registre A del servidor de correu

```bash
dig @10.26.50.2 mail.alumnat.demoasixcloud2025.cat A
```

**Resultat esperat:**

```
;; ANSWER SECTION:
mail.alumnat.demoasixcloud2025.cat. 3600 IN A 10.26.50.10
```

### 8.3 Consulta curta vs. detallada

```bash
# Resultat curt (només la resposta)
dig @10.26.50.2 alumnat.demoasixcloud2025.cat MX +short

# Resultat detallat amb traça completa
dig @10.26.50.2 alumnat.demoasixcloud2025.cat MX +trace
```

> **Exercici:** Compara la sortida de `dig +short` amb `dig +trace`. Quina informació
> addicional proporciona la traça? Per què pot ser útil per a la depuració?

---

## Pas 9: Analitzar els logs del servidor durant l'enviament

Obre un segon terminal i monitoritza els logs en temps real:

```bash
./lab.sh logs mail-alumnat
```

Des del contenidor `client-swaks`, envia un correu:

```bash
swaks \
  --to alumne1@alumnat.demoasixcloud2025.cat \
  --from alumne2@alumnat.demoasixcloud2025.cat \
  --server 10.26.50.10 \
  --port 25 \
  --header "Subject: Test de logs"
```

### Entrades de log rellevants

Busca al log les entrades relacionades:

```
postfix/smtpd[...]: connect from unknown[10.26.50.200]
postfix/smtpd[...]: XXXXXXX: client=unknown[10.26.50.200]
postfix/cleanup[...]: XXXXXXX: message-id=<...>
postfix/qmgr[...]: XXXXXXX: from=<alumne2@alumnat.demoasixcloud2025.cat>, ...
postfix/local[...]: XXXXXXX: to=<alumne1@alumnat.demoasixcloud2025.cat>, ... status=sent (delivered to maildir)
postfix/qmgr[...]: XXXXXXX: removed
```

**Flux al log:**
1. **smtpd**: Accepta la connexió entrant del client
2. **cleanup**: Processa les capçaleres del missatge
3. **qmgr**: El gestor de cues programa l'entrega
4. **local**: Entrega el correu a la bústia local (Maildir)
5. **qmgr**: Elimina el missatge de la cua (entregat correctament)

> **Exercici:** Identifica el `queue ID` (ex: `XXXXXXX`) i segueix-lo a través
> de totes les entrades del log per traçar el camí complet del correu.

---

## Pas 10: Captura i anàlisi d'una transacció SMTP completa

### 10.1 Iniciar la captura

Des d'un terminal al host:

```bash
./pcap.sh mail-alumnat eth1 "port 25"
```

### 10.2 Enviar un correu durant la captura

Des del contenidor `client-swaks`:

```bash
swaks \
  --to alumne1@alumnat.demoasixcloud2025.cat \
  --from alumne2@alumnat.demoasixcloud2025.cat \
  --server 10.26.50.10 \
  --port 25 \
  --header "Subject: Captura SMTP" \
  --body "Correu per a l'anàlisi de paquets"
```

Prem `Ctrl+C` al terminal de captura.

### 10.3 Analitzar amb Wireshark

```bash
wireshark mail-alumnat_eth1_*.pcapng
```

**Què buscar:**
1. **TCP Handshake** (SYN, SYN-ACK, ACK) — establiment de connexió
2. **220 banner** — resposta del servidor
3. **EHLO** — identificació del client
4. **MAIL FROM / RCPT TO** — sobre del missatge (envelope)
5. **DATA** — cos del missatge (capçaleres + cos)
6. **QUIT** — tancament de la sessió
7. **TCP Teardown** (FIN, ACK) — tancament de connexió

> **Compara:** Fes la mateixa captura al port 465 (`./pcap.sh mail-alumnat eth1 "port 465"`)
> i observa que amb TLS el contingut és completament il·legible.

---

## Pas 11: Experiments addicionals amb swaks

### 11.1 Simular un enviament a un destinatari inexistent

```bash
swaks \
  --to noexisteix@alumnat.demoasixcloud2025.cat \
  --from alumne2@alumnat.demoasixcloud2025.cat \
  --server 10.26.50.10 \
  --port 25
```

**Resultat esperat:** El servidor hauria de rebutjar el destinatari amb un codi d'error `550`:

```
<** 550 5.1.1 <noexisteix@alumnat.demoasixcloud2025.cat>: Recipient address rejected
```

### 11.2 Simular un relay no autoritzat

```bash
swaks \
  --to extern@gmail.com \
  --from alumne1@alumnat.demoasixcloud2025.cat \
  --server 10.26.50.10 \
  --port 25
```

**Resultat esperat:** Si el servidor està correctament configurat, hauria de rebutjar
el relay amb un codi `554` o `550`:

```
<** 554 5.7.1 <extern@gmail.com>: Relay access denied
```

> **Reflexió:** Un servidor de correu que permet relay obert (open relay) pot ser
> abusat per enviar spam. Per això és fonamental restringir el relay.

---

## Pas 12: Aturar el laboratori

```bash
./lab.sh destroy
```

---

## Resum de l'Etapa 3

| Aspecte | Valor |
|---------|-------|
| Eina principal | swaks (Swiss Army Knife for SMTP) |
| Node nou | `client-swaks` (10.26.50.200) |
| Ports provats | 25 (SMTP), 587 (submission + STARTTLS), 465 (SMTPS) |
| Autenticació | LOGIN (base64) |
| Topologia | `topologies/etapa3.yml` |

### Opcions principals de swaks

| Opció | Descripció |
|-------|-----------|
| `--to` | Adreça del destinatari |
| `--from` | Adreça del remitent |
| `--server` | IP o nom del servidor SMTP |
| `--port` | Port del servidor (25, 587, 465) |
| `--tls` | Activar STARTTLS (per al port 587) |
| `--tlsc` | Activar TLS implícit (per al port 465) |
| `--auth LOGIN` | Mecanisme d'autenticació LOGIN |
| `--auth-user` | Usuari per a l'autenticació |
| `--auth-password` | Contrasenya per a l'autenticació |
| `--header "Subject: ..."` | Afegir capçalera personalitzada |
| `--body "..."` | Cos del missatge |
| `--attach /path/fitxer` | Adjuntar un fitxer |
| `-v` | Mode verbose (més detall) |

---

## Observacions importants

- **SMTP és un protocol de text:** A diferència de protocols binaris, SMTP utilitza comandes i respostes en text pla legible. Això el fa ideal per a l'aprenentatge i la depuració.

- **Sobre (envelope) vs. capçaleres (headers):** El sobre SMTP (`MAIL FROM` / `RCPT TO`) determina el camí d'entrega del missatge. Les capçaleres (`From:` / `To:`) són les que veu l'usuari al client de correu. Poden ser **diferents** — i això és exactament com funciona el spoofing de correu electrònic.

- **Codis de resposta SMTP:** Tots els codis de resposta segueixen un patró:
  - **2xx**: Èxit (ex: 250 OK)
  - **3xx**: Acció intermèdia requerida (ex: 354 Start mail input)
  - **4xx**: Error temporal (ex: 421 Service not available)
  - **5xx**: Error permanent (ex: 550 Mailbox not found)

- **Open relay és perillós:** Un servidor que accepta retransmetre correus per a qualsevol domini (open relay) serà abusat pels spammers. La configuració per defecte de Postfix ho impedeix, però cal verificar-ho.

- **swaks com a eina de diagnòstic:** swaks no és només una eina d'enviament de correus. És una eina de diagnòstic completa que mostra cada pas de la transacció SMTP, permetent identificar problemes de configuració, autenticació o xifrat.

---

## Preguntes de reflexió — Etapa 3

1. Descriu els passos d'una transacció SMTP completa (EHLO, MAIL FROM, RCPT TO, DATA, QUIT). Quin codi de resposta retorna el servidor a cada pas si tot és correcte?

2. Quina diferència hi ha entre enviar un correu pel port 25, pel port 587 i pel port 465? En quins casos es requereix autenticació? En quins s'utilitza TLS?

3. Per què el port 587 requereix autenticació però el port 25 no sempre la requereix? Quin és el propòsit original de cada port i per a qui està destinat?

4. Què revela la resposta EHLO del servidor sobre les seves capacitats? Quines extensions SMTP importants pot anunciar (STARTTLS, AUTH, PIPELINING, SIZE)?

5. Explica com interpretar la sortida de swaks: què signifiquen els símbols `->` i `<-`? Com pots identificar si l'enviament ha estat exitós o ha fallat?

6. Què és un open relay i per què és perillós? Com pots verificar amb swaks si un servidor accepta relay no autoritzat? Quin codi d'error hauria de retornar?

7. Quina diferència hi ha entre el sobre SMTP (envelope: MAIL FROM / RCPT TO) i les capçaleres del missatge (headers: From: / To:)? Per què poden ser diferents i quines implicacions de seguretat té?

8. Què és la prioritat d'un registre MX i com funciona? Si un domini té dos registres MX amb prioritats 10 i 20, a quin servidor s'enviarà el correu primer? Què passa si el primer no respon?

9. Com pots verificar amb swaks si un servidor de correu accepta connexions al port 25? Descriu com faries una prova de connectivitat bàsica sense enviar cap correu real.

10. Quina diferència hi ha entre la sortida de `dig +short` i `dig +trace` per a un registre MX? Quina informació addicional proporciona la traça i per què pot ser útil per diagnosticar problemes d'entrega de correu?
