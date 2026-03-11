# Laboratori de Servidors de Correu — Etapa 1: Correu bàsic amb docker-mailserver (sense TLS)

## Objectiu

Desplegar un servidor de correu electrònic funcional basat en **docker-mailserver** (DMS) per al domini `alumnat.demoasixcloud2025.cat` dins d'un entorn de xarxa virtualitzat amb Containerlab. L'alumnat configurarà un client Thunderbird per enviar i rebre correus entre comptes del **mateix domini**, observant el funcionament dels protocols SMTP i IMAP **sense cap capa de xifrat (TLS)**. Això permet entendre l'arquitectura bàsica del correu electrònic i els riscos de seguretat del text pla.

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
  |       |                     (MX, A per alumnat.demoasixcloud2025) |
  |       |                                                          |
  |       +---- [proxy]         10.26.50.3   Nginx proxy invers      |
  |       |                                                          |
  |       +---- [mail-alumnat]  10.26.50.10  docker-mailserver       |
  |       |                     Postfix (SMTP) + Dovecot (IMAP)      |
  |       |                     Ports: 25 (SMTP), 143 (IMAP)        |
  |       |                                                          |
  |       +---- [thunderbird1]  10.26.50.100 Client de correu        |
  |                              (jlesage/thunderbird via noVNC)     |
  |                                                                  |
  +------------------------------------------------------------------+
```

**Domini:** `alumnat.demoasixcloud2025.cat` --> `10.26.50.10`
**Registre MX:** `alumnat.demoasixcloud2025.cat` --> `mail.alumnat.demoasixcloud2025.cat`

---

## Prerequisits

### Al host Linux

```bash
# 1. Docker instal·lat i funcionant
docker version

# 2. Containerlab instal·lat
sudo bash -c "$(curl -sL https://get.containerlab.dev)"

# 3. Clonar el repositori i situar-se al directori del lab
cd 007-mailserver-lab/

# 4. Verificar que Docker i Containerlab estan disponibles
docker version && containerlab version
```

---

## Pas 1: Construir les imatges Docker personalitzades

El laboratori requereix una imatge personalitzada per al switch (Linux bridge).
La resta de nodes utilitzen imatges oficials:

- **Servidor de correu:** `ghcr.io/docker-mailserver/docker-mailserver:latest`
- **Client Thunderbird:** `jlesage/thunderbird:latest`
- **Router:** `frrouting/frr:latest`
- **DNS:** `coredns/coredns:latest`
- **Proxy:** `nginx:alpine`

```bash
# Construir totes les imatges personalitzades
./lab.sh build
```

> **Nota:** Aquesta comanda construeix la imatge `mail-switch:latest` necessària
> perquè el node `switch-lan` funcioni com un bridge L2 entre tots els nodes.

---

## Pas 2: Desplegar el laboratori (Etapa 1)

```bash
./lab.sh deploy 1
```

> **Nota:** Aquesta comanda requereix `sudo` (Containerlab necessita privilegis
> per crear les interfícies de xarxa virtuals).

Comprova que els contenidors estan actius:

```bash
./lab.sh status
```

Hauries de veure 5 nodes: `switch-lan`, `router-frr`, `coredns`, `proxy`, `mail-alumnat`, `thunderbird1`.

> **Important:** La topologia desplegada correspon al fitxer `topologies/etapa1.yml`.
> En aquesta etapa, el servidor DMS funciona amb `SSL_TYPE: ""` (sense TLS).

---

## Pas 3: Configurar els comptes de correu

Executa l'script de configuració post-desplegament per crear els comptes d'usuari:

```bash
./lab.sh setup 1
```

Això crea automàticament dos comptes al servidor docker-mailserver:

| Compte | Contrasenya |
|--------|-------------|
| `alumne1@alumnat.demoasixcloud2025.cat` | `Alumne1.2025` |
| `alumne2@alumnat.demoasixcloud2025.cat` | `Alumne2.2025` |

### Verificació manual dels comptes

Pots verificar que els comptes s'han creat correctament:

```bash
./lab.sh shell mail-alumnat
setup email list
```

Hauries de veure els dos comptes llistats.

---

## Pas 4: Verificar la resolució DNS

Abans de configurar el client de correu, és fonamental verificar que el DNS intern resol correctament els registres del domini:

```bash
# Des del host o des de qualsevol contenidor amb dig/nslookup:
./lab.sh shell mail-alumnat

# Consultar el registre MX (mail exchanger)
dig @10.26.50.2 alumnat.demoasixcloud2025.cat MX

# Consultar el registre A del servidor de correu
dig @10.26.50.2 mail.alumnat.demoasixcloud2025.cat A
```

**Resultats esperats:**

```
;; ANSWER SECTION:
alumnat.demoasixcloud2025.cat. 3600 IN MX 10 mail.alumnat.demoasixcloud2025.cat.

;; ANSWER SECTION:
mail.alumnat.demoasixcloud2025.cat. 3600 IN A 10.26.50.10
```

> **Reflexió:** El registre MX indica a quin servidor s'han d'enviar els correus
> per al domini. El registre A resol el nom d'aquest servidor a la seva IP.

---

## Pas 5: Accedir a Thunderbird via noVNC

Thunderbird s'executa dins d'un contenidor amb interfície gràfica accessible via navegador web (noVNC).

Obre el navegador al host i navega a:

```
http://localhost:5800
```

S'obrirà la interfície de Thunderbird dins del navegador. Si no es carrega, espera uns segons (el contenidor necessita temps per inicialitzar-se).

> **Alternativa via proxy:** Si has configurat el proxy Nginx, també pots accedir
> via `http://localhost:8080` (si la ruta està configurada).

---

## Pas 6: Configurar el compte d'alumne1 a Thunderbird

### 6.1 Crear el compte manualment

1. A Thunderbird, ves a **Menu > Account Settings > Account Actions > Add Mail Account**
2. Introdueix les dades:
   - **Nom:** `Alumne 1`
   - **Adreça:** `alumne1@alumnat.demoasixcloud2025.cat`
   - **Contrasenya:** `Alumne1.2025`
3. Fes clic a **Configure manually** (Configuració manual)
4. Configura els servidors:

**Servidor entrant (IMAP):**

| Paràmetre | Valor |
|-----------|-------|
| Protocol | IMAP |
| Servidor | `10.26.50.10` |
| Port | `143` |
| Seguretat | Cap (None) |
| Autenticació | Contrasenya normal |

**Servidor sortint (SMTP):**

| Paràmetre | Valor |
|-----------|-------|
| Servidor | `10.26.50.10` |
| Port | `25` |
| Seguretat | Cap (None) |
| Autenticació | Contrasenya normal |

5. Fes clic a **Re-test** per verificar la connexió
6. Thunderbird pot mostrar un avís de seguretat perquè no hi ha TLS. Accepta'l.
7. Fes clic a **Done**

> **Important:** Estem configurant el correu **sense cap xifrat** expressament.
> A l'Etapa 2 afegirem TLS per protegir les comunicacions.

---

## Pas 7: Enviar un correu d'alumne1 a alumne2

1. A Thunderbird (amb el compte d'alumne1), fes clic a **Write** (Escriu)
2. Omple els camps:
   - **To:** `alumne2@alumnat.demoasixcloud2025.cat`
   - **Subject:** `Primer correu de prova`
   - **Cos:** `Hola alumne2! Aquest és el primer correu del laboratori.`
3. Fes clic a **Send** (Envia)

### Verificar a la safata de sortida

Comprova que el correu apareix a la carpeta **Sent** del compte d'alumne1.

---

## Pas 8: Configurar el compte d'alumne2 i verificar la recepció

### 8.1 Afegir un segon compte a Thunderbird

Repeteix el procés del Pas 6, però amb les dades d'alumne2:

- **Adreça:** `alumne2@alumnat.demoasixcloud2025.cat`
- **Contrasenya:** `Alumne2.2025`
- Mateixos paràmetres IMAP/SMTP (servidor `10.26.50.10`, ports 143/25, sense TLS)

### 8.2 Verificar la recepció

1. Selecciona el compte d'alumne2 a Thunderbird
2. Fes clic a **Get Messages** (Obtenir missatges)
3. Hauries de veure el correu enviat per alumne1 a la safata d'entrada (**Inbox**)
4. Obre'l i verifica que el contingut és correcte

> **Prova addicional:** Respon el correu des d'alumne2 i verifica que alumne1 el rep.

---

## Pas 9: Capturar el tràfic de xarxa (SMTP/IMAP en clar)

Aquesta és la part més reveladora de l'etapa: veure com les credencials i el contingut dels correus viatgen **completament en text pla**.

### 9.1 Iniciar la captura

Des d'un terminal al host:

```bash
# Capturar tràfic SMTP (port 25) i IMAP (port 143) al servidor de correu
./pcap.sh mail-alumnat eth1 "port 25 or port 143"
```

Mentrestant, des de Thunderbird:
1. Envia un correu nou d'alumne1 a alumne2
2. Consulta la safata d'entrada d'alumne2

Quan acabis, prem `Ctrl+C` per aturar la captura.

### 9.2 Analitzar la captura

```bash
# Obre la captura amb Wireshark (si el tens instal·lat)
wireshark mail-alumnat_eth1_*.pcapng
```

**Què hauries de veure:**

- **Transacció SMTP:** Comandes `EHLO`, `MAIL FROM`, `RCPT TO`, `DATA`, el cos del correu en text pla
- **Autenticació IMAP:** Comanda `LOGIN` amb l'usuari i la contrasenya **visibles**
- **Contingut dels correus:** Tot el text del missatge sense xifrar

> **Conclusió de seguretat:** Qualsevol dispositiu a la mateixa xarxa pot interceptar
> les credencials i el contingut dels correus. Això és inacceptable en un entorn de producció.

---

## Pas 10: Analitzar els logs del servidor

```bash
# Veure els logs en temps real
./lab.sh logs mail-alumnat
```

Busca entrades com:

- `postfix/smtpd`: connexions SMTP entrants
- `postfix/smtp`: entrega de correus
- `dovecot/imap-login`: connexions IMAP dels clients
- `dovecot/lda`: entrega local dels correus a les bústies

> **Exercici:** Identifica al log la seqüència completa d'un correu enviat des
> d'alumne1 i rebut per alumne2.

---

## Pas 11: Explorar l'estructura interna del servidor

### 11.1 Bústies de correu

```bash
./lab.sh shell mail-alumnat

# Veure l'estructura de bústies (format Maildir)
ls -la /var/mail/alumnat.demoasixcloud2025.cat/alumne1/
ls -la /var/mail/alumnat.demoasixcloud2025.cat/alumne2/

# Veure un correu en brut
cat /var/mail/alumnat.demoasixcloud2025.cat/alumne2/new/*
```

### 11.2 Components del servidor

```bash
# Verificar que Postfix (MTA) està en execució
supervisorctl status postfix

# Verificar que Dovecot (MDA/IMAP) està en execució
supervisorctl status dovecot
```

---

## Pas 12: Aturar el laboratori

```bash
./lab.sh destroy
```

---

## Resum de l'Etapa 1

| Aspecte | Valor |
|---------|-------|
| Protocol d'enviament | SMTP (port 25) |
| Protocol de recepció | IMAP (port 143) |
| Xifrat | Cap (text pla) |
| Autenticació | Usuari/contrasenya en clar |
| Servidor de correu | docker-mailserver (Postfix + Dovecot) |
| DNS intern | CoreDNS (`10.26.50.2`) |
| Registre MX | `alumnat.demoasixcloud2025.cat` → `mail.alumnat.demoasixcloud2025.cat` |
| Client GUI | Thunderbird via noVNC (port 5800) |
| Proxy | Nginx (`10.26.50.3`, port 8080 al host) |
| Topologia | `topologies/etapa1.yml` |
| Comptes | `alumne1` / `Alumne1.2025`, `alumne2` / `Alumne2.2025` |

---

## Observacions importants

- **Sense TLS = text pla:** En aquesta etapa, tant les credencials d'autenticació com el contingut dels correus viatgen sense xifrar. Qualsevol node a la xarxa pot interceptar-los amb una simple captura de paquets. **Mai** s'ha de desplegar un servidor de correu sense TLS en producció.

- **Arquitectura MUA/MTA/MDA:** El correu electrònic involucra tres components fonamentals:
  - **MUA** (Mail User Agent): el client de correu (Thunderbird). Redacta i llegeix correus.
  - **MTA** (Mail Transfer Agent): el servidor SMTP (Postfix). Enruta i entrega correus entre servidors.
  - **MDA** (Mail Delivery Agent): el servei que diposita els correus a la bústia de l'usuari (Dovecot/LDA).

- **DNS és essencial:** Sense resolució DNS funcional (registres MX i A), el correu electrònic no pot funcionar. El registre MX indica a quin servidor s'han de lliurar els correus d'un domini.

- **Port 25 vs. ports de submissió:** El port 25 és el port estàndard per a la comunicació entre servidors (MTA-to-MTA). En un entorn de producció, els clients utilitzen els ports 587 (STARTTLS) o 465 (TLS implícit) per a l'enviament autenticat.

- **Containerlab i xarxa:** Tots els nodes es connecten al `switch-lan` (un contenidor Linux amb bridge-utils) que actua com un switch L2. Les IPs s'assignen via comandes `exec` post-startup als contenidors.

---

## Preguntes de reflexió — Etapa 1

1. Quina diferència hi ha entre els protocols SMTP i IMAP? Quin s'utilitza per enviar correus i quin per llegir-los? Quins ports estàndard utilitza cadascun?

2. Explica els rols de MUA, MTA i MDA en el flux d'un correu electrònic. Identifica quin programari del laboratori correspon a cada rol.

3. Per què és perillós utilitzar un servidor de correu sense TLS en un entorn de producció? Quines dades concretes queden exposades en una captura de xarxa?

4. Què és un registre MX (Mail Exchanger) i quin paper juga en el lliurament del correu electrònic? Què passaria si no existís cap registre MX per al domini?

5. Quan l'alumne1 envia un correu a l'alumne2 (ambdós al mateix domini), quin camí segueix el missatge dins del servidor? Quins components intervenen?

6. Quin és el paper del servidor DNS (CoreDNS) en l'arquitectura del correu electrònic? Per què és imprescindible que el servidor de correu pugui resoldre noms DNS?

7. Quines responsabilitats té Postfix dins del docker-mailserver i quines té Dovecot? Per què es necessiten tots dos serveis?

8. Si examines un correu electrònic en format brut (raw), quines capçaleres (headers) pots identificar? Quina informació proporcionen `From`, `To`, `Date`, `Message-ID` i `Received`?

9. Quina és la diferència funcional entre el port 25 (SMTP) i el port 143 (IMAP)? Quins tipus d'operacions es realitzen a cadascun?

10. Què conté el directori `/var/mail/` del servidor? Quin format de bústia utilitza docker-mailserver (Maildir o mbox)? Quina diferència hi ha entre els subdirectoris `new/`, `cur/` i `tmp/`?
