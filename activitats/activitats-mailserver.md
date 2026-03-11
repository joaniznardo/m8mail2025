# Activitats del Laboratori de Servidors de Correu

**Mòdul**: Serveis de Xarxa i Internet
**Cicle**: ASIX (2n curs)
**Durada**: 3 sessions de 2 hores + 1 repte final d'1 hora (7 hores totals)

---

## Índex

1. [Sessió 1: Descoberta del correu electrònic (Etapes 1–2)](#sessió-1-descoberta-del-correu-electrònic-etapes-12)
2. [Sessió 2: Seguretat i depuració (Etapes 3–4)](#sessió-2-seguretat-i-depuració-etapes-34)
3. [Sessió 3: Múltiples servidors (Etapes 5–6)](#sessió-3-múltiples-servidors-etapes-56)
4. [Repte final](#repte-final)
5. [Solucions](#solucions)

---

## Preparació inicial

Abans de començar, construeix les imatges personalitzades del laboratori:

```bash
cd ~/007-mailserver-lab
./lab.sh build
```

**Verificació**:

```bash
docker images | grep -E "mail-switch|mail-client-swaks|mail-acme"
```

Hauries de veure almenys la imatge `mail-switch`.

---

# Sessió 1: Descoberta del correu electrònic (Etapes 1–2)

**Objectius**:
- Comprendre l'arquitectura del correu electrònic (MUA, MTA, MDA)
- Identificar els protocols i ports associats
- Analitzar el tràfic SMTP i IMAP en una captura de xarxa
- Entendre la necessitat de TLS per protegir les comunicacions

---

## 1.1 Activitats de reflexió (Autoavaluació)

Respon les següents preguntes **abans** de tocar el laboratori:

### Activitat 1. Dibuixa l'arquitectura del correu electrònic

Dibuixa un diagrama que mostri el flux complet d'un correu electrònic des que l'usuari A l'envia fins que l'usuari B el llegeix. El diagrama ha d'incloure:

- **MUA** (Mail User Agent): client de correu (ex: Thunderbird)
- **MTA** (Mail Transfer Agent): servidor SMTP (ex: Postfix)
- **MDA** (Mail Delivery Agent): servei d'entrega a bústia (ex: Dovecot/LDA)

**Preguntes:**

1. Quin component redacta i envia els correus?
2. Quin component enruta els correus entre servidors?
3. Quin component diposita el correu a la bústia de l'usuari destinatari?
4. A la nostra infraestructura, quin programari correspon a cada rol?

---

### Activitat 2. Llista de ports del correu electrònic

Completa la taula següent amb tots els ports utilitzats pels protocols de correu:

| Port | Protocol | TLS | Ús principal |
|------|----------|-----|--------------|
| 25   |          |     |              |
| 143  |          |     |              |
| 465  |          |     |              |
| 587  |          |     |              |
| 993  |          |     |              |
| 110  |          |     |              |
| 995  |          |     |              |

**Pregunta:** Quins ports s'utilitzen per a la comunicació entre servidors (relay) i quins per a la submissió de correus des d'un client?

---

### Activitat 3. Diferències entre SMTP, IMAP i POP3

Respon les preguntes següents:

1. Quina funció té el protocol SMTP? En quina direcció viatgen els correus (enviament o recepció)?
2. Quina funció té el protocol IMAP? Quina és la seva principal diferència respecte a POP3?
3. Per què un client de correu necessita configurar **dos** servidors (entrant i sortint)?
4. Quin avantatge té IMAP sobre POP3 per a un usuari que accedeix al correu des de múltiples dispositius?

---

## 1.2 Activitats d'identificació (Anàlisi del laboratori)

### Activitat 4. Desplegar i explorar l'etapa 1

Desplega l'etapa 1 i identifica tots els nodes de la topologia:

```bash
./lab.sh deploy 1
./lab.sh setup 1
./lab.sh status
```

**Tasca**: Completa la taula amb la informació dels contenidors desplegats:

| Node | IP | Funció | Imatge Docker |
|------|----|--------|---------------|
| switch-lan | — | | |
| router-frr | | | |
| coredns | | | |
| proxy | | | |
| mail-alumnat | | | |
| thunderbird1 | | | |

### Autocorrecció

```bash
echo "=== NODES ==="
docker ps --filter "label=clab-node-name" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" | grep mailserver
echo ""
echo "=== IPs ==="
for node in router-frr coredns proxy mail-alumnat thunderbird1; do
    IP=$(docker exec clab-mailserver-lab-$node ip -4 addr show eth1 2>/dev/null | grep -oP 'inet \K[\d.]+' || echo "N/A")
    echo "$node: $IP"
done
```

---

### Activitat 5. Capturar i analitzar una transacció SMTP

Captura el tràfic SMTP (port 25) mentre envies un correu des de Thunderbird.

**Pas 1**: Inicia la captura des del host:

```bash
./pcap.sh mail-alumnat eth1 "port 25 or port 143"
```

**Pas 2**: Accedeix a Thunderbird (http://localhost:5800), configura el compte d'alumne1 i envia un correu a alumne2.

**Pas 3**: Atura la captura (Ctrl+C) i obre-la amb Wireshark:

```bash
wireshark mail-alumnat_eth1_*.pcapng
```

**Tasca**: Identifica a la captura els passos següents de la transacció SMTP i anota els codis de resposta del servidor:

| Pas | Comanda/Resposta | Codi |
|-----|-----------------|------|
| 1 | Banner del servidor | |
| 2 | EHLO | |
| 3 | MAIL FROM | |
| 4 | RCPT TO | |
| 5 | DATA | |
| 6 | Fi del missatge (.) | |
| 7 | QUIT | |

**Pregunta**: Pots veure el contingut del correu (assumpte, cos) a la captura? Per què?

---

### Activitat 6. Examinar les capçaleres d'un correu en brut

Des de Thunderbird, amb el correu rebut al compte d'alumne2:

1. Obre el missatge
2. Ves a **View → Message Source** (o `Ctrl+U`)

**Tasca**: Identifica i explica el significat de les capçaleres següents:

| Capçalera | Valor observat | Funció |
|-----------|---------------|--------|
| `From:` | | |
| `To:` | | |
| `Date:` | | |
| `Subject:` | | |
| `Message-ID:` | | |
| `Received:` | | |
| `X-Mailer:` | | |

**Pregunta**: Pot la capçalera `From:` ser diferent del `MAIL FROM` del sobre SMTP? Quines implicacions de seguretat té?

---

### Activitat 7. Verificar la resolució DNS

Des del contenidor `mail-alumnat`, executa les consultes DNS següents:

```bash
./lab.sh shell mail-alumnat

# Registre MX
dig @10.26.50.2 alumnat.demoasixcloud2025.cat MX

# Registre A del servidor de correu
dig @10.26.50.2 mail.alumnat.demoasixcloud2025.cat A

# Registre invers (PTR) — si existeix
dig @10.26.50.2 -x 10.26.50.10
```

**Tasca**: Anota els resultats i respon:

1. Quin és el servidor MX per al domini `alumnat.demoasixcloud2025.cat`? Quina prioritat té?
2. A quina IP resol `mail.alumnat.demoasixcloud2025.cat`?
3. Existeix un registre PTR per a la IP `10.26.50.10`? Per què és important el DNS invers per al correu electrònic?

### Autocorrecció

```bash
echo "=== VERIFICACIÓ DNS ==="
echo "MX:" && docker exec clab-mailserver-lab-mail-alumnat dig @10.26.50.2 alumnat.demoasixcloud2025.cat MX +short
echo "A:" && docker exec clab-mailserver-lab-mail-alumnat dig @10.26.50.2 mail.alumnat.demoasixcloud2025.cat A +short
echo "PTR:" && docker exec clab-mailserver-lab-mail-alumnat dig @10.26.50.2 -x 10.26.50.10 +short
```

---

## 1.3 Activitats de troubleshooting (Troba i resol problemes)

### Activitat 8. Thunderbird no pot connectar al servidor de correu

**Escenari**: Un alumne ha configurat Thunderbird amb els paràmetres següents i no pot connectar-se:

| Paràmetre | Valor configurat |
|-----------|-----------------|
| Servidor IMAP | `10.26.50.10` |
| Port IMAP | **993** |
| Seguretat IMAP | **SSL/TLS** |
| Servidor SMTP | `10.26.50.10` |
| Port SMTP | **465** |
| Seguretat SMTP | **SSL/TLS** |

**Context**: Estem a l'Etapa 1 (sense TLS).

**Tasques**:

1. Identifica per què Thunderbird no pot connectar.
2. Quins ports i quin nivell de seguretat hauria d'usar a l'Etapa 1?
3. Corregeix la configuració i verifica que funciona.

**Pista**: A l'Etapa 1, el servidor DMS està configurat amb `SSL_TYPE: ""` (sense TLS). Quins ports funcionen sense TLS?

### Verificació

```bash
# Comprova quins ports estan oberts al servidor de correu
docker exec clab-mailserver-lab-mail-alumnat sh -c '
    for port in 25 143 465 587 993; do
        nc -z -w1 localhost $port 2>/dev/null && echo "Port $port: OBERT" || echo "Port $port: TANCAT"
    done
'
```

---

### Activitat 9. El correu s'envia però no es rep

**Escenari**: L'alumne1 envia un correu a alumne2 des de Thunderbird. El missatge apareix a la carpeta "Sent" però alumne2 no el rep.

**Procediment de diagnòstic**:

1. Comprova els logs del servidor:

```bash
./lab.sh logs mail-alumnat 2>&1 | tail -30
```

2. Verifica que el DNS resol correctament:

```bash
docker exec clab-mailserver-lab-mail-alumnat dig @10.26.50.2 alumnat.demoasixcloud2025.cat MX +short
```

3. Comprova que els comptes existeixen:

```bash
docker exec clab-mailserver-lab-mail-alumnat setup email list
```

4. Comprova la bústia de l'alumne2:

```bash
docker exec clab-mailserver-lab-mail-alumnat ls /var/mail/alumnat.demoasixcloud2025.cat/alumne2/new/
```

**Tasques**:

1. Segueix el procediment de diagnòstic i identifica on es trenca el flux.
2. Quines entrades del log t'ajuden a localitzar el problema?
3. Si el log mostra `status=bounced`, què significa? I si mostra `status=deferred`?

---

### Activitat 10. Contrasenyes en text pla (demostrar la necessitat de TLS)

**Escenari**: El professor demana a l'alumnat que demostri per què no s'ha d'usar mai un servidor de correu sense TLS.

**Pas 1**: Inicia la captura al servidor:

```bash
./pcap.sh mail-alumnat eth1 "port 143"
```

**Pas 2**: Des de Thunderbird, consulta la safata d'entrada de l'alumne1 (això força una autenticació IMAP).

**Pas 3**: Atura la captura i analitza-la.

**Tasques**:

1. Localitza la comanda `LOGIN` a la captura. Pots veure l'usuari i la contrasenya?
2. Quin seria el risc en una xarxa Wi-Fi pública?
3. Quins ports i protocol hauríem d'usar per evitar aquest problema? (Pista: IMAPS port 993)

### Autocorrecció

```bash
echo "=== DEMOSTRACIÓ TLS ==="
echo "Sense TLS (port 143), la comanda LOGIN és visible:"
echo '  * LOGIN alumne1@alumnat.demoasixcloud2025.cat Alumne1.2025'
echo ""
echo "Amb TLS (port 993), la captura mostra:"
echo '  [TLS Application Data - contingut xifrat]'
echo ""
echo "Ports segurs: IMAPS=993, SMTPS=465, Submission=587+STARTTLS"
```

### Finalització Sessió 1

```bash
./lab.sh destroy
```

---

# Sessió 2: Seguretat i depuració (Etapes 3–4)

**Objectius**:
- Comprendre SPF, DKIM i DMARC com a mecanismes d'autenticació del correu
- Diferenciar STARTTLS i TLS implícit
- Utilitzar swaks per depurar transaccions SMTP
- Diagnosticar errors de certificat i configuració DNS

---

## 2.1 Activitats de reflexió (Autoavaluació)

### Activitat 11. Protecció contra la suplantació: SPF, DKIM i DMARC

Respon les preguntes següents:

1. **SPF**: Contra quina amenaça protegeix? Qui consulta el registre SPF i en quin moment?
2. **DKIM**: Com garanteix que el contingut d'un correu no ha estat modificat en trànsit? Quin tipus de criptografia utilitza?
3. **DMARC**: Quin paper juga com a coordinador de SPF i DKIM? Quines són les tres polítiques possibles (`none`, `quarantine`, `reject`)?
4. Per què cap d'aquests mecanismes és suficient per si sol? Quines amenaces específiques cobreix cadascun?

---

### Activitat 12. STARTTLS vs TLS implícit

Respon:

1. En una connexió amb **STARTTLS**, en quin moment comença el xifrat? La connexió inicial és en text pla o xifrada?
2. En una connexió amb **TLS implícit**, la connexió comença directament xifrada?
3. Quin dels dos és més vulnerable a un atac de *downgrade* (on un atacant impedeix l'actualització a TLS)? Per què?
4. Quins ports usen cadascun per a SMTP? I per a IMAP?

---

## 2.2 Activitats d'identificació (Anàlisi del laboratori)

### Activitat 13. Tres modes d'enviament amb swaks

Desplega l'etapa 3 i utilitza swaks per enviar correus de tres maneres diferents:

```bash
./lab.sh deploy 3
./lab.sh setup 3
./lab.sh shell client-swaks
```

**Mode 1 — Port 25, sense autenticació, sense TLS:**

```bash
swaks \
  --to alumne1@alumnat.demoasixcloud2025.cat \
  --from alumne2@alumnat.demoasixcloud2025.cat \
  --server 10.26.50.10 \
  --port 25 \
  --header "Subject: Mode 1 - Port 25"
```

**Mode 2 — Port 587, autenticació, STARTTLS:**

```bash
swaks \
  --to alumne1@alumnat.demoasixcloud2025.cat \
  --from alumne2@alumnat.demoasixcloud2025.cat \
  --server 10.26.50.10 \
  --port 587 \
  --tls \
  --auth LOGIN \
  --auth-user alumne2@alumnat.demoasixcloud2025.cat \
  --auth-password 'Alumne2.2025' \
  --header "Subject: Mode 2 - Port 587 STARTTLS"
```

**Mode 3 — Port 465, autenticació, TLS implícit:**

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
  --header "Subject: Mode 3 - Port 465 TLS implícit"
```

**Tasca**: Completa la taula comparativa:

| Aspecte | Port 25 | Port 587 | Port 465 |
|---------|---------|----------|----------|
| Autenticació requerida? | | | |
| TLS? | | | |
| Opció swaks per TLS | | | |
| Codi de resposta final | | | |
| Ús principal | | | |

### Autocorrecció

```bash
echo "=== VERIFICACIÓ ENVIAMENT ==="
docker exec clab-mailserver-lab-mail-alumnat sh -c '
    TOTAL=$(ls /var/mail/alumnat.demoasixcloud2025.cat/alumne1/new/ 2>/dev/null | wc -l)
    echo "Correus a la bústia alumne1: $TOTAL (esperat: 3)"
'
```

---

### Activitat 14. Analitzar capçaleres DKIM i Authentication-Results

Desplega l'etapa 4 (amb Rspamd activat):

```bash
./lab.sh destroy
./lab.sh deploy 4
./lab.sh setup 4
```

Envia un correu amb swaks:

```bash
docker exec clab-mailserver-lab-client-swaks \
    swaks \
    --to alumne1@alumnat.demoasixcloud2025.cat \
    --from alumne2@alumnat.demoasixcloud2025.cat \
    --server 10.26.50.10 \
    --port 587 \
    --tls \
    --auth LOGIN \
    --auth-user alumne2@alumnat.demoasixcloud2025.cat \
    --auth-password 'Alumne2.2025' \
    --header "Subject: Prova DKIM"
```

A Thunderbird (http://localhost:5800), obre el correu rebut per alumne1 i visualitza el codi font (**View → Message Source** o `Ctrl+U`).

**Tasca**: Identifica les capçaleres següents i anota els valors:

| Capçalera | Valor observat |
|-----------|---------------|
| `DKIM-Signature: v=` | |
| `DKIM-Signature: a=` (algorisme) | |
| `DKIM-Signature: d=` (domini) | |
| `DKIM-Signature: s=` (selector) | |
| `Authentication-Results: dkim=` | |
| `Authentication-Results: spf=` | |
| `Authentication-Results: dmarc=` | |

**Pregunta**: Si `dkim=pass` però `spf=fail`, què faria un servidor receptor amb política DMARC `p=quarantine`?

---

### Activitat 15. Verificar els registres SPF, DKIM i DMARC amb dig

Executa les consultes DNS des del contenidor client-swaks o mail-alumnat:

```bash
# SPF
dig @10.26.50.2 alumnat.demoasixcloud2025.cat TXT +short

# DKIM (selector: mail)
dig @10.26.50.2 mail._domainkey.alumnat.demoasixcloud2025.cat TXT +short

# DMARC
dig @10.26.50.2 _dmarc.alumnat.demoasixcloud2025.cat TXT +short
```

**Tasca**: Anota els valors i respon:

1. Quin és el significat de `v=spf1 mx ~all`? Què canviaria si fos `-all` en lloc de `~all`?
2. Quin selector DKIM s'utilitza? On es troba la clau pública?
3. Quina política DMARC s'aplica? Quina adreça rep els informes agregats?

### Autocorrecció

```bash
echo "=== VERIFICACIÓ DNS AUTENTICACIÓ ==="
echo "SPF:" && docker exec clab-mailserver-lab-mail-alumnat dig @10.26.50.2 alumnat.demoasixcloud2025.cat TXT +short | grep spf
echo "DKIM:" && docker exec clab-mailserver-lab-mail-alumnat dig @10.26.50.2 mail._domainkey.alumnat.demoasixcloud2025.cat TXT +short | head -1
echo "DMARC:" && docker exec clab-mailserver-lab-mail-alumnat dig @10.26.50.2 _dmarc.alumnat.demoasixcloud2025.cat TXT +short
```

---

## 2.3 Activitats de troubleshooting (Troba i resol problemes)

### Activitat 16. La verificació DKIM falla

**Escenari**: Un correu enviat des del servidor de l'alumnat arriba al destinatari amb `dkim=fail` a la capçalera `Authentication-Results`.

**Diagnòstic**: L'administrador sospita que el registre DNS DKIM és incorrecte.

**Pas 1**: Comprova la clau pública publicada al DNS:

```bash
dig @10.26.50.2 mail._domainkey.alumnat.demoasixcloud2025.cat TXT +short
```

**Pas 2**: Comprova la clau privada al servidor:

```bash
docker exec clab-mailserver-lab-mail-alumnat \
    ls -la /tmp/docker-mailserver/opendkim/keys/alumnat.demoasixcloud2025.cat/
```

**Pas 3**: Compara el contingut del registre DNS (`mail.txt`) amb el que s'ha publicat:

```bash
docker exec clab-mailserver-lab-mail-alumnat \
    cat /tmp/docker-mailserver/opendkim/keys/alumnat.demoasixcloud2025.cat/mail.txt
```

**Tasques**:

1. Quines causes poden provocar un `dkim=fail`? Llista'n almenys tres.
2. Si el registre DNS conté una clau pública diferent de la que correspon a la clau privada del servidor, com ho resoldries?
3. Si el selector configurat a Rspamd és `mail` però el registre DNS utilitza `default._domainkey`, funcionarà? Per què?

**Pista**: Les causes més comunes són: clau pública incorrecta al DNS, selector diferent, o espais/salts de línia al valor del registre TXT.

---

### Activitat 17. swaks retorna "Connection refused"

**Escenari**: L'alumne intenta enviar un correu amb swaks però rep l'error `Connection refused`.

**Preparació** (simula l'error):

```bash
# Intenta connectar a un port incorrecte
docker exec clab-mailserver-lab-client-swaks \
    swaks --to alumne1@alumnat.demoasixcloud2025.cat \
    --server 10.26.50.10 --port 2525
```

**Diagnòstic**:

1. Verifica la connectivitat bàsica:

```bash
docker exec clab-mailserver-lab-client-swaks ping -c 2 10.26.50.10
```

2. Comprova quins ports SMTP estan oberts:

```bash
docker exec clab-mailserver-lab-client-swaks sh -c '
    for port in 25 465 587 2525; do
        nc -z -w2 10.26.50.10 $port 2>/dev/null && echo "Port $port: OBERT" || echo "Port $port: TANCAT"
    done
'
```

3. Verifica l'estat de Postfix al servidor:

```bash
docker exec clab-mailserver-lab-mail-alumnat supervisorctl status postfix
```

**Tasques**:

1. Per què el port 2525 no funciona?
2. Quins ports SMTP hauria d'usar l'alumne?
3. Si tots els ports estan tancats, quina seria la primera cosa a comprovar?

---

### Activitat 18. Error de certificat a Thunderbird

**Escenari**: L'alumne ha desplegat l'etapa 2 (amb TLS) i ha configurat Thunderbird amb IMAPS (port 993). Thunderbird mostra un error de certificat: *"The certificate is not trusted because it is self-signed"* o *"The certificate expired"*.

**Diagnòstic**:

1. Inspecciona el certificat del servidor:

```bash
echo | openssl s_client -connect 10.26.50.10:993 2>/dev/null | openssl x509 -noout -subject -issuer -dates
```

2. Verifica que els fitxers de certificat existeixen al servidor:

```bash
docker exec clab-mailserver-lab-mail-alumnat ls -la /etc/ssl/mail/
```

3. Comprova la configuració SSL de DMS:

```bash
docker exec clab-mailserver-lab-mail-alumnat sh -c 'echo SSL_TYPE=$SSL_TYPE'
```

**Tasques**:

1. Si l'emissor del certificat (`Issuer`) és el mateix que el subjecte (`Subject`), què significa? (Pista: certificat autosignat)
2. Si la data `notAfter` ja ha passat, com es regeneraria el certificat?
3. Si el certificat és per al domini `alumnat.demoasixcloud2025.cat` però l'alumne es connecta per IP (`10.26.50.10`), per què Thunderbird pot mostrar un avís?

### Finalització Sessió 2

```bash
./lab.sh destroy
```

---

# Sessió 3: Múltiples servidors (Etapes 5–6)

**Objectius**:
- Comparar les arquitectures de DMS, Stalwart i Mailcow
- Comprendre els criteris per escollir un servidor de correu
- Treballar amb Roundcube i SOGo com a clients webmail
- Diagnosticar problemes de connectivitat entre serveis

---

## 3.1 Activitats de reflexió (Autoavaluació)

### Activitat 19. Comparar arquitectures

Completa la taula comparativa amb les dades que recordis de la documentació:

| Característica | docker-mailserver (DMS) | Stalwart | Mailcow |
|---------------|------------------------|----------|---------|
| Llenguatge principal | | | |
| Nombre de contenidors | | | |
| MTA (SMTP) | | | |
| MDA (IMAP) | | | |
| Configuració | | | |
| Administració | | | |
| Webmail integrat | | | |
| Emmagatzematge | | | |
| RAM mínima | | | |
| JMAP? | | | |

**Pregunta**: Quin model preferiries per a un servidor personal? I per a una empresa de 500 empleats? Justifica la resposta.

---

### Activitat 20. Criteris d'elecció d'un servidor de correu

Per a cada escenari, indica quin servidor de correu recomanaries i per què:

| Escenari | Servidor | Justificació |
|----------|----------|-------------|
| Freelance amb domini propi i VPS de 512 MB RAM | | |
| Empresa de 50 empleats amb equip d'IT | | |
| Universitat de 10.000 estudiants | | |
| Startup que vol protocols moderns (JMAP) | | |
| Migració des d'Exchange/Office365 | | |

---

## 3.2 Activitats d'identificació (Anàlisi del laboratori)

### Activitat 21. Comparar configuracions de DMS i Stalwart

Desplega l'etapa 5:

```bash
./lab.sh deploy 5
./lab.sh setup 5
```

**Pas 1**: Examina la configuració de DMS (variables d'entorn):

```bash
docker inspect clab-mailserver-lab-mail-alumnat --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -E "SSL_|ENABLE_|PERMIT_|OVERRIDE"
```

**Pas 2**: Examina la configuració de Stalwart (fitxer TOML):

```bash
docker exec clab-mailserver-lab-mail-professorat cat /opt/stalwart-mail/etc/config.toml | head -60
```

**Pas 3**: Compara l'API de Stalwart amb la CLI de DMS:

```bash
# DMS: gestió per CLI
docker exec clab-mailserver-lab-mail-alumnat setup email list

# Stalwart: gestió per API REST
docker exec clab-mailserver-lab-client-swaks \
    curl -s -u admin:Admin.2025 http://10.26.50.20:8080/api/account/profe1@professorat.demoasixcloud2025.cat | python3 -m json.tool 2>/dev/null || echo "(necessita python3)"
```

**Tasca**: Documenta tres diferències clau entre l'enfocament de configuració de DMS i Stalwart.

---

### Activitat 22. Roundcube: enviar, rebre i analitzar el tràfic HTTP

Accedeix a Roundcube al navegador:

```
http://localhost:8081
```

Inicia sessió amb `profe1@professorat.demoasixcloud2025.cat` / `Profe1.2025`.

**Pas 1**: Envia un correu a `profe2@professorat.demoasixcloud2025.cat`.

**Pas 2**: Tanca sessió i entra amb `profe2` per verificar la recepció.

**Pas 3**: Captura el tràfic entre Roundcube i Stalwart:

```bash
./pcap.sh mail-professorat eth1 "port 143 or port 587"
```

Mentrestant, entra a Roundcube i consulta la bústia d'entrada.

**Tasques**:

1. Roundcube emmagatzema els correus o els llegeix del servidor via IMAP? Què passa si el servidor cau?
2. A la captura, pots veure tràfic IMAP entre Roundcube (`10.26.50.102`) i Stalwart (`10.26.50.20`)?
3. Quina diferència hi ha entre accedir al correu amb Roundcube i amb Thunderbird, des del punt de vista del protocol?

---

### Activitat 23. Serveis de Mailcow

Desplega l'etapa 6:

```bash
./lab.sh destroy
./lab.sh deploy 6
./lab.sh setup 6
```

**Tasca**: Investiga l'arquitectura multi-contenidor de Mailcow. Si els contenidors de Mailcow estan en execució, llista'ls:

```bash
docker ps --filter "name=mailcow" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" 2>/dev/null || echo "Mailcow no desplegat com a stack Docker Compose"
```

Completa la taula amb els serveis de Mailcow:

| Contenidor | Servei | Funció | Port principal |
|-----------|--------|--------|----------------|
| postfix-mailcow | Postfix | | 25, 465, 587 |
| dovecot-mailcow | Dovecot | | 143, 993 |
| nginx-mailcow | Nginx | | 8080, 8443 |
| rspamd-mailcow | Rspamd | | |
| mysql-mailcow | MariaDB | | 3306 |
| redis-mailcow | Redis | | 6379 |
| sogo-mailcow | SOGo | | |
| php-fpm-mailcow | PHP-FPM | | |
| clamd-mailcow | ClamAV | | |

**Pregunta**: Per què Mailcow necessita ~12 contenidors quan DMS només en necessita 1 i Stalwart també 1? Quins avantatges i inconvenients té l'arquitectura de microserveis?

---

## 3.3 Activitats de troubleshooting (Troba i resol problemes)

### Activitat 24. Roundcube no pot connectar a Stalwart

**Escenari**: Roundcube mostra l'error *"Connection to storage server failed"* quan un usuari intenta iniciar sessió.

**Diagnòstic**:

1. Verifica que Stalwart està en execució:

```bash
docker exec clab-mailserver-lab-mail-professorat ps aux | grep stalwart
```

2. Comprova la connectivitat des de Roundcube a Stalwart:

```bash
docker exec clab-mailserver-lab-roundcube sh -c '
    nc -z -w2 10.26.50.20 143 && echo "IMAP: OK" || echo "IMAP: FALLA"
    nc -z -w2 10.26.50.20 587 && echo "SMTP: OK" || echo "SMTP: FALLA"
'
```

3. Comprova les variables de configuració de Roundcube:

```bash
docker exec clab-mailserver-lab-roundcube sh -c '
    echo "IMAP Host: $ROUNDCUBEMAIL_DEFAULT_HOST"
    echo "IMAP Port: $ROUNDCUBEMAIL_DEFAULT_PORT"
    echo "SMTP Host: $ROUNDCUBEMAIL_SMTP_SERVER"
    echo "SMTP Port: $ROUNDCUBEMAIL_SMTP_PORT"
'
```

**Tasques**:

1. Si `ROUNDCUBEMAIL_DEFAULT_HOST` apunta a `10.26.50.10` (DMS) en lloc de `10.26.50.20` (Stalwart), quin seria l'error?
2. Si el port IMAP configurat és `993` (IMAPS) però Stalwart només escolta al port `143` (IMAP sense TLS), què passaria?
3. Com corregiries cada error?

**Pista**: Les variables d'entorn de Roundcube defineixen a quin servidor IMAP/SMTP es connecta.

---

### Activitat 25. La interfície web de Mailcow no és accessible

**Escenari**: L'alumne intenta accedir a `http://mail.alumni.demoasixcloud2025.cat` però rep un error 502 (Bad Gateway) o la pàgina no carrega.

**Diagnòstic**:

1. Verifica que el node `mail-alumni` té IP assignada:

```bash
docker exec clab-mailserver-lab-mail-alumni ip -4 addr show eth1 2>/dev/null | grep inet
```

2. Comprova que el proxy Nginx té la ruta configurada:

```bash
docker exec clab-mailserver-lab-proxy cat /etc/nginx/conf.d/default.conf | grep -A 5 "alumni"
```

3. Comprova la connectivitat del proxy cap al node Mailcow:

```bash
docker exec clab-mailserver-lab-proxy sh -c '
    nc -z -w2 10.26.50.30 8080 && echo "Mailcow HTTP: OK" || echo "Mailcow HTTP: FALLA"
'
```

**Tasques**:

1. Si la connectivitat al port 8080 falla, quines poden ser les causes? (Pista: contenidors de Mailcow no arrencats, port incorrecte)
2. Si el proxy no té la ruta `alumni` configurada, com l'afegiries?
3. Quina diferència hi ha entre un error 502 (Bad Gateway) i un error 504 (Gateway Timeout)?

---

# Repte final

**Durada**: 1 hora
**Tipus**: Individual o en parelles

---

## Activitat 26. Disseny d'una infraestructura de correu completa

### Escenari

L'empresa fictícia **TechCat S.L.** et contracta per dissenyar la seva infraestructura de correu electrònic. L'empresa té tres departaments:

- **Enginyeria** (80 empleats) — `enginyeria.techcat.cat`
- **Administració** (20 empleats) — `admin.techcat.cat`
- **Comercial** (30 empleats) — `comercial.techcat.cat`

### Requisits

1. Cada departament ha de tenir el seu propi subdomini de correu
2. Tots els correus han de viatjar xifrats (TLS obligatori)
3. Cal implementar SPF, DKIM i DMARC per a cada domini
4. L'empresa vol un client webmail per a l'accés des de navegadors
5. El departament d'enginyeria vol suport per a JMAP
6. El pressupost permet un sol servidor físic amb 16 GB de RAM

### Lliuraments

**A. Diagrama d'arquitectura** (30% de la nota):

Dibuixa la topologia completa incloent:
- Servidors de correu (quin per a cada domini i per què)
- Servidor DNS amb tots els registres necessaris
- Proxy invers
- Clients (webmail i/o escriptori)
- Xarxa amb adreces IP

**B. Registres DNS** (20% de la nota):

Llista tots els registres DNS necessaris per a cada domini:

| Tipus | Nom | Valor |
|-------|-----|-------|
| MX | `enginyeria.techcat.cat` | |
| A | `mail.enginyeria.techcat.cat` | |
| TXT (SPF) | `enginyeria.techcat.cat` | |
| TXT (DKIM) | `mail._domainkey.enginyeria.techcat.cat` | |
| TXT (DMARC) | `_dmarc.enginyeria.techcat.cat` | |
| ... | (repetir per admin i comercial) | |

**C. Elecció de servidors** (30% de la nota):

Per a cada departament, justifica l'elecció del servidor de correu:

| Departament | Servidor escollit | Justificació (mínim 3 raons) |
|-------------|------------------|------------------------------|
| Enginyeria | | |
| Administració | | |
| Comercial | | |

**D. Pla d'implementació** (20% de la nota):

Descriu en 5-8 passos l'ordre d'implementació, incloent:
- Generació de certificats TLS
- Desplegament dels servidors
- Configuració DNS
- Creació de comptes
- Proves de validació

### Rúbrica

| Criteri | Excel·lent (10) | Notable (8) | Bé (6) | Insuficient (<5) |
|---------|----------------|-------------|--------|-------------------|
| Diagrama | Complet, clar, tots els components | Complet amb petits errors | Parcial, falten components | Incomplet o absent |
| DNS | Tots els registres correctes | >80% correctes | >50% correctes | <50% correctes |
| Justificació | Raons tècniques sòlides i contextualitzades | Raons correctes però poc detallades | Raons vagues | Sense justificació |
| Pla | Ordenat, viable, amb proves | Ordenat amb mancances | Desordenat però viable | No viable |

---

# Solucions

## Sessió 1

### Activitat 1 — Arquitectura MUA/MTA/MDA

1. **MUA** (Mail User Agent): Thunderbird. Redacta, envia i llegeix correus.
2. **MTA** (Mail Transfer Agent): Postfix. Enruta correus entre servidors via SMTP.
3. **MDA** (Mail Delivery Agent): Dovecot (LDA). Diposita el correu a la bústia de l'usuari.
4. A la nostra infraestructura: MUA = Thunderbird, MTA = Postfix (dins de DMS), MDA = Dovecot (dins de DMS).

El flux complet: Thunderbird (MUA) → Postfix (MTA emissor, port 25/587/465) → Postfix (MTA receptor, port 25) → Dovecot LDA (MDA) → Bústia Maildir → Thunderbird (MUA, via IMAP port 143/993).

---

### Activitat 2 — Ports del correu electrònic

| Port | Protocol | TLS | Ús principal |
|------|----------|-----|--------------|
| 25 | SMTP | STARTTLS (opcional) | Relay entre servidors (MTA-to-MTA) |
| 143 | IMAP | STARTTLS (opcional) | Lectura de correu (sense TLS per defecte) |
| 465 | SMTPS | TLS implícit | Submissió de clients (TLS des de l'inici) |
| 587 | SMTP Submission | STARTTLS (obligatori) | Submissió de clients (actualització a TLS) |
| 993 | IMAPS | TLS implícit | Lectura de correu (TLS des de l'inici) |
| 110 | POP3 | STARTTLS (opcional) | Descàrrega de correu (sense TLS per defecte) |
| 995 | POP3S | TLS implícit | Descàrrega de correu (TLS des de l'inici) |

Comunicació entre servidors: port 25. Submissió de clients: ports 587 i 465.

---

### Activitat 3 — SMTP vs IMAP vs POP3

1. **SMTP** s'usa per enviar correus (del client al servidor i entre servidors). La direcció és d'enviament.
2. **IMAP** s'usa per llegir correus que romanen al servidor. POP3 descarrega els correus i els esborra del servidor (per defecte).
3. Perquè l'enviament (SMTP) i la lectura (IMAP/POP3) són protocols completament diferents.
4. IMAP manté els correus al servidor, de manera que es veuen des de qualsevol dispositiu. POP3 els descarrega localment i s'esborren del servidor.

---

### Activitat 4 — Nodes de l'etapa 1

| Node | IP | Funció | Imatge Docker |
|------|----|--------|---------------|
| switch-lan | — (L2) | Switch virtual (bridge) | mail-switch:latest |
| router-frr | 10.26.50.1 | Gateway de la xarxa | frrouting/frr:latest |
| coredns | 10.26.50.2 | Servidor DNS intern | coredns/coredns:latest |
| proxy | 10.26.50.3 | Proxy invers web | nginx:alpine |
| mail-alumnat | 10.26.50.10 | Servidor de correu (DMS) | docker-mailserver:latest |
| thunderbird1 | 10.26.50.100 | Client de correu (GUI) | jlesage/thunderbird:latest |

---

### Activitat 5 — Transacció SMTP

| Pas | Comanda/Resposta | Codi |
|-----|-----------------|------|
| 1 | Banner: `220 mail.alumnat.(...) ESMTP` | 220 |
| 2 | `EHLO` → capacitats del servidor | 250 |
| 3 | `MAIL FROM:<alumne1@(...)>` | 250 |
| 4 | `RCPT TO:<alumne2@(...)>` | 250 |
| 5 | `DATA` | 354 |
| 6 | `.` (fi del missatge) | 250 |
| 7 | `QUIT` | 221 |

Sí, el contingut del correu és completament visible a la captura perquè no hi ha TLS (Etapa 1).

---

### Activitat 6 — Capçaleres del correu

| Capçalera | Funció |
|-----------|--------|
| `From:` | Adreça del remitent (visible a l'usuari) |
| `To:` | Adreça del destinatari |
| `Date:` | Data i hora d'enviament |
| `Subject:` | Assumpte del missatge |
| `Message-ID:` | Identificador únic del missatge |
| `Received:` | Cadena de servidors per on ha passat el correu (traçabilitat) |
| `X-Mailer:` | Programari client utilitzat per enviar |

Sí, `From:` (capçalera) pot ser diferent del `MAIL FROM` (sobre). Això permet spoofing de correu — per això existeixen SPF, DKIM i DMARC.

---

### Activitat 7 — DNS

1. El servidor MX és `mail.alumnat.demoasixcloud2025.cat` amb prioritat 10.
2. Resol a `10.26.50.10`.
3. El DNS invers (PTR) és important perquè molts servidors de correu rebutgen missatges de servidors sense registre PTR vàlid (anti-spam).

---

### Activitat 8 — Thunderbird no connecta (port incorrecte)

**Problema**: A l'Etapa 1 no hi ha TLS configurat (`SSL_TYPE: ""`). Els ports 993 (IMAPS) i 465 (SMTPS) no estan disponibles perquè requereixen TLS.

**Solució**: Usar els ports sense TLS:
- IMAP: port **143**, seguretat **Cap (None)**
- SMTP: port **25**, seguretat **Cap (None)**

---

### Activitat 9 — Correu no rebut

El procediment de diagnòstic és:

1. **Logs**: Buscar el `queue ID` i seguir-lo. Si mostra `status=sent (delivered to maildir)`, el correu s'ha entregat correctament i el problema pot ser que Thunderbird no ha refrescat la bústia.
2. **`status=bounced`**: El correu ha estat rebutjat permanentment (compte inexistent, domini incorrecte).
3. **`status=deferred`**: El correu s'ha posat a la cua per reintentar (error temporal, servidor de destinació no disponible).

Causes comunes: DNS incorrecte, compte de destinatari inexistent, bústia plena, error de permisos al Maildir.

---

### Activitat 10 — Contrasenyes en text pla

1. Sí, la comanda `LOGIN` d'IMAP mostra l'usuari i la contrasenya en text pla: `* LOGIN alumne1@alumnat.demoasixcloud2025.cat Alumne1.2025`.
2. En una xarxa Wi-Fi pública, qualsevol persona amb un sniffer (Wireshark, tcpdump) pot capturar les credencials.
3. Cal usar IMAPS (port 993) amb TLS implícit o IMAP (port 143) amb STARTTLS.

---

## Sessió 2

### Activitat 11 — SPF, DKIM, DMARC

1. **SPF** protegeix contra la suplantació del servidor emissor. El servidor receptor consulta el registre SPF (TXT) del domini del remitent per verificar que la IP del servidor emissor està autoritzada.
2. **DKIM** signa digitalment el missatge amb criptografia asimètrica (clau privada al servidor, clau pública al DNS). El receptor verifica la signatura consultant el DNS. Garanteix integritat (el missatge no ha estat modificat).
3. **DMARC** coordina SPF i DKIM sota una política de domini: `none` (monitoritza), `quarantine` (spam), `reject` (rebutja). Requereix que almenys un dels dos passi i estigui alineat amb el domini `From`.
4. SPF no sobreviu al reenviament. DKIM no verifica el servidor emissor. DMARC no funciona sense SPF i DKIM. Junts cobreixen: suplantació de servidor (SPF), manipulació de contingut (DKIM), i suplantació del domini visible (DMARC).

---

### Activitat 12 — STARTTLS vs TLS implícit

1. **STARTTLS**: La connexió comença en text pla. Després de l'intercanvi inicial (EHLO), el client envia la comanda `STARTTLS` per actualitzar a TLS.
2. **TLS implícit**: La connexió TLS s'estableix immediatament, abans de qualsevol intercanvi de dades.
3. STARTTLS és més vulnerable a atacs de *downgrade* perquè un atacant pot interceptar i eliminar la comanda STARTTLS, forçant la comunicació en text pla.
4. SMTP: STARTTLS = port 587, TLS implícit = port 465. IMAP: STARTTLS = port 143, TLS implícit = port 993.

---

### Activitat 13 — Tres modes amb swaks

| Aspecte | Port 25 | Port 587 | Port 465 |
|---------|---------|----------|----------|
| Autenticació requerida? | No | Sí | Sí |
| TLS? | No (oportunista) | Sí (STARTTLS) | Sí (implícit) |
| Opció swaks per TLS | (cap) | `--tls` | `--tlsc` |
| Codi de resposta final | 250 | 250 | 250 |
| Ús principal | Relay (MTA-to-MTA) | Submissió (client) | Submissió (client) |

---

### Activitat 14 — Capçaleres DKIM

Valors esperats:

| Capçalera | Valor esperat |
|-----------|--------------|
| `DKIM-Signature: v=` | `1` |
| `DKIM-Signature: a=` | `rsa-sha256` |
| `DKIM-Signature: d=` | `alumnat.demoasixcloud2025.cat` |
| `DKIM-Signature: s=` | `mail` |
| `Authentication-Results: dkim=` | `pass` |
| `Authentication-Results: spf=` | `pass` |
| `Authentication-Results: dmarc=` | `pass` |

Si `dkim=pass` però `spf=fail` amb política `p=quarantine`: DMARC passa si almenys un dels dos (SPF o DKIM) passa **i** està alineat amb el domini `From`. Amb `dkim=pass` alineat, DMARC pot resultar `pass` i el correu es lliuraria normalment. Però si DKIM tampoc estigués alineat, DMARC fallaria i el correu aniria a la carpeta de spam.

---

### Activitat 15 — Registres DNS

1. `v=spf1 mx ~all` significa: autoritza els servidors definits als registres MX (`mx`), i marca com a sospitosos (softfail `~`) els correus d'altres servidors. Amb `-all` (hardfail), els correus no autoritzats es rebutjarien directament.
2. El selector és `mail` (a `mail._domainkey.alumnat.(...)`). La clau pública es troba al valor del registre TXT.
3. La política és `p=none` (monitorització). L'adreça `rua=mailto:postmaster@alumnat.(...)` rep els informes agregats.

---

### Activitat 16 — DKIM fail

Causes possibles d'un `dkim=fail`:

1. **Clau pública incorrecta al DNS**: El valor `p=` no correspon a la clau privada del servidor.
2. **Selector incorrecte**: El servidor signa amb selector `mail` però el DNS té el registre a `default._domainkey`.
3. **Espais o salts de línia** dins del valor del registre TXT al DNS que corrompen la clau.
4. **Modificació del missatge en trànsit** (per exemple, un relay que afegeix capçaleres que invaliden la signatura).
5. **Clau privada no carregada** a Rspamd (el servidor no signa els missatges).

Solució: Regenerar les claus (`./lab.sh setup 4`), copiar el valor exacte de `mail.txt` al registre DNS, i verificar amb `dig`.

---

### Activitat 17 — Connection refused

1. El port 2525 no funciona perquè Postfix no escolta en aquest port. Els ports SMTP estàndard configurats són 25, 465 i 587.
2. L'alumne hauria d'usar el port 25 (sense autenticació), 587 (amb STARTTLS) o 465 (amb TLS implícit).
3. Si tots els ports estan tancats: comprovar que Postfix està en execució (`supervisorctl status postfix`), que el contenidor `mail-alumnat` està actiu, i que no hi ha regles de firewall que bloquegin el tràfic.

---

### Activitat 18 — Error de certificat

1. Si `Issuer` = `Subject`, és un certificat autosignat. No està signat per una CA reconeguda (com Let's Encrypt). Els clients no el confien per defecte.
2. Regenerar el certificat amb `./lab.sh certs alumnat` i reiniciar els serveis del servidor de correu.
3. El certificat és emès per al nom de domini (`mail.alumnat.demoasixcloud2025.cat`), no per a la IP `10.26.50.10`. Quan el client es connecta per IP, el nom no coincideix amb el CN/SAN del certificat i Thunderbird mostra un avís de seguretat.

---

## Sessió 3

### Activitat 19 — Comparar arquitectures

| Característica | docker-mailserver (DMS) | Stalwart | Mailcow |
|---------------|------------------------|----------|---------|
| Llenguatge principal | C (Postfix/Dovecot) + Bash | Rust | C (Postfix/Dovecot) + PHP |
| Nombre de contenidors | 1 | 1 | ~12 |
| MTA (SMTP) | Postfix | Integrat (Rust) | Postfix |
| MDA (IMAP) | Dovecot | Integrat (Rust) | Dovecot |
| Configuració | Variables d'entorn | config.toml + API REST | mailcow.conf + Web UI |
| Administració | CLI (`setup`) | Web UI + API REST | Web UI completa |
| Webmail integrat | Cap (extern) | Cap (extern) | SOGo (integrat) |
| Emmagatzematge | Maildir (fitxers) | RocksDB (embedded) | MariaDB + Maildir |
| RAM mínima | ~512 MB | ~256 MB | ~4 GB |
| JMAP? | No | Sí (natiu) | No |

Servidor personal: **Stalwart** (lleuger, fàcil, un sol binari). Empresa de 500 empleats: **Mailcow** (UI completa, SOGo amb calendari/contactes/ActiveSync, gestió visual per a administradors no tècnics).

---

### Activitat 20 — Criteris d'elecció

| Escenari | Servidor | Justificació |
|----------|----------|-------------|
| Freelance amb VPS de 512 MB | Stalwart | Mínim consum de RAM (~256 MB), fàcil de configurar, un sol binari |
| Empresa de 50 empleats amb IT | DMS | Flexible, components Unix provats, equip tècnic pot personalitzar |
| Universitat de 10.000 estudiants | Mailcow | UI d'administració completa, SOGo per a accés web, ActiveSync per a mòbils |
| Startup amb JMAP | Stalwart | Únic servidor amb suport JMAP natiu, modern, eficient |
| Migració des d'Exchange | Mailcow | SOGo ofereix ActiveSync (sincronització correu/calendari/contactes) |

---

### Activitat 21 — Configuracions DMS vs Stalwart

Tres diferències clau:

1. **Format**: DMS usa variables d'entorn (clau=valor); Stalwart usa fitxer TOML (estructurat, amb seccions).
2. **Administració**: DMS usa la comanda `setup` dins del contenidor (CLI); Stalwart ofereix API REST i interfície web.
3. **Modularitat**: DMS empaqueta múltiples processos Unix (Postfix, Dovecot, Rspamd) coordinats per `supervisord`; Stalwart és un sol binari que implementa tots els protocols.

---

### Activitat 22 — Roundcube

1. Roundcube **no emmagatzema** correus. Llegeix del servidor via IMAP i envia via SMTP. Si el servidor cau, Roundcube no pot funcionar.
2. Sí, la captura mostra tràfic IMAP (port 143) entre `10.26.50.102` (Roundcube) i `10.26.50.20` (Stalwart).
3. Thunderbird es connecta directament al servidor IMAP. Roundcube actua com a intermediari: l'usuari accedeix a Roundcube via HTTP (navegador) i Roundcube es connecta al servidor via IMAP. El tràfic es duplica: HTTP (navegador→Roundcube) + IMAP (Roundcube→servidor).

---

### Activitat 23 — Serveis Mailcow

| Contenidor | Servei | Funció |
|-----------|--------|--------|
| postfix-mailcow | Postfix | Servidor SMTP (MTA), enruta i entrega correus |
| dovecot-mailcow | Dovecot | Servidor IMAP/POP3 (MDA), accés a les bústies |
| nginx-mailcow | Nginx | Proxy web per a la UI d'administració i SOGo |
| rspamd-mailcow | Rspamd | Filtre anti-spam + signatura DKIM |
| mysql-mailcow | MariaDB | Base de dades relacional (dominis, comptes, configuració) |
| redis-mailcow | Redis | Cache de sessions, rate limiting, cues |
| sogo-mailcow | SOGo | Webmail + calendari + contactes (CalDAV/CardDAV) |
| php-fpm-mailcow | PHP-FPM | Backend PHP per a la interfície d'administració |
| clamd-mailcow | ClamAV | Antivirus per a correus entrants |

Mailcow usa microserveis per: actualitzacions independents, aïllament de fallades, escalabilitat de components individuals. Inconvenients: complexitat operacional, consum de recursos, dificultat de diagnòstic.

---

### Activitat 24 — Roundcube no connecta

1. Si `ROUNDCUBEMAIL_DEFAULT_HOST` apunta a DMS (`10.26.50.10`) en lloc de Stalwart (`10.26.50.20`), Roundcube intentaria autenticar els comptes de professorat contra DMS, que no coneix aquests comptes. Error: *"Login failed"* o *"Authentication failed"*.
2. Si el port IMAP configurat és 993 però Stalwart només escolta al 143, la connexió fallaria perquè Roundcube intentaria fer un handshake TLS al port 143 (que espera text pla) o simplement no obtindria resposta al port 993 (tancat).
3. Corregir les variables d'entorn del contenidor Roundcube: `ROUNDCUBEMAIL_DEFAULT_HOST=10.26.50.20` i `ROUNDCUBEMAIL_DEFAULT_PORT=143`.

---

### Activitat 25 — Mailcow UI no accessible

1. Causes de la fallada al port 8080: els contenidors de Mailcow no s'han iniciat (cal `docker compose up -d`), el port està configurat diferent a `mailcow.conf`, o el contenidor `nginx-mailcow` ha fallat.
2. Per afegir la ruta al proxy, caldria editar la configuració de Nginx del contenidor `proxy` i afegir un `server` block o `location` que faci proxy_pass cap a `http://10.26.50.30:8080`.
3. **502 Bad Gateway**: el proxy ha contactat el backend però ha rebut una resposta invàlida (el backend ha fallat o ha tornat un error). **504 Gateway Timeout**: el proxy ha contactat el backend però no ha rebut resposta dins del temps límit (el backend és massa lent o no respon).

---

## Repte final

### Activitat 26 — Solució orientativa

**A. Arquitectura proposada:**

```
Xarxa: 10.10.0.0/24

[DNS]           10.10.0.2    CoreDNS
[Proxy]         10.10.0.3    Nginx reverse proxy
[Enginyeria]    10.10.0.10   Stalwart (suport JMAP, lleuger)
[Administració] 10.10.0.20   DMS (flexible, personalitzable)
[Comercial]     10.10.0.30   Mailcow (UI completa, SOGo, ActiveSync)
[Webmail]       10.10.0.40   Roundcube (per enginyeria i administració)
```

**B. Registres DNS (exemple per enginyeria):**

| Tipus | Nom | Valor |
|-------|-----|-------|
| MX | `enginyeria.techcat.cat` | `mail.enginyeria.techcat.cat` (prioritat 10) |
| A | `mail.enginyeria.techcat.cat` | `10.10.0.10` |
| TXT (SPF) | `enginyeria.techcat.cat` | `v=spf1 mx -all` |
| TXT (DKIM) | `mail._domainkey.enginyeria.techcat.cat` | `v=DKIM1; k=rsa; p=...` |
| TXT (DMARC) | `_dmarc.enginyeria.techcat.cat` | `v=DMARC1; p=quarantine; rua=mailto:postmaster@enginyeria.techcat.cat` |

(Repetir per `admin.techcat.cat` i `comercial.techcat.cat`)

**C. Elecció de servidors:**

| Departament | Servidor | Justificació |
|-------------|----------|-------------|
| Enginyeria | Stalwart | 1) Suport JMAP natiu (requisit), 2) Lleuger (~256 MB RAM), 3) Modern i eficient per a equips tècnics |
| Administració | DMS | 1) Flexible i personalitzable, 2) Components provats (Postfix/Dovecot), 3) Fàcil d'integrar amb eines existents |
| Comercial | Mailcow | 1) SOGo amb ActiveSync per a comercials amb mòbil, 2) Calendari/contactes integrats, 3) UI d'administració per gestionar bústies sense CLI |

RAM estimada: Stalwart (~256 MB) + DMS (~512 MB) + Mailcow (~4 GB) + DNS/Proxy (~256 MB) ≈ 5 GB. Dins del pressupost de 16 GB.

**D. Pla d'implementació:**

1. Configurar el DNS (registres MX, A per a cada domini)
2. Generar certificats TLS per als tres dominis (Let's Encrypt amb validació DNS)
3. Desplegar Stalwart per a `enginyeria.techcat.cat` i crear comptes
4. Desplegar DMS per a `admin.techcat.cat` i crear comptes
5. Desplegar Mailcow per a `comercial.techcat.cat`, crear domini i comptes
6. Publicar registres SPF, DKIM i DMARC per als tres dominis
7. Desplegar Roundcube i configurar-lo per als dominis que ho necessitin
8. Proves de validació: enviar correus intra-domini, verificar capçaleres DKIM/SPF, comprovar webmail

---

## Notes finals

- Les solucions proporcionades són orientatives. Es valorarà la comprensió demostrada a les explicacions.
- És acceptable arribar a solucions alternatives si són tècnicament correctes i estan justificades.
- Per a les activitats de troubleshooting, el més important és el procés de diagnòstic (identificar, analitzar, resoldre), no només la resposta final.
