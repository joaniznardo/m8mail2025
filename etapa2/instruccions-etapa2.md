# Laboratori de Servidors de Correu — Etapa 2: Certificats TLS amb Let's Encrypt

## Objectiu

Generar certificats reals de **Let's Encrypt** per al domini `alumnat.demoasixcloud2025.cat` utilitzant la validació DNS amb **Cloudflare**, i configurar el servidor docker-mailserver amb **TLS** per protegir les comunicacions SMTP i IMAP. L'alumnat compararà el tràfic xifrat amb el tràfic en clar de l'Etapa 1 i reconfigurarà Thunderbird per utilitzar connexions segures.

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
  |       |                     Ports: 465 (SMTPS), 587 (STARTTLS)  |
  |       |                            993 (IMAPS)                   |
  |       |                                                          |
  |       +---- [thunderbird1]  10.26.50.100 Client de correu        |
  |       |                                                          |
  |       +---- [acme]          10.26.50.250 Client ACME             |
  |                              (acme.sh + Cloudflare DNS)          |
  |                                                                  |
  +------------------------------------------------------------------+

  Cloudflare DNS API
       ^
       | Validació DNS-01 (TXT _acme-challenge)
       |
  [acme] genera certificats Let's Encrypt
       |
       v
  certs/alumnat/ --> muntat a mail-alumnat:/etc/ssl/mail/
```

**Certificats:** `certs/alumnat/{fullchain.pem, key.pem}`

---

## Prerequisits

### Al host Linux

```bash
# 1. Etapa 1 completada correctament (o capacitat de desplegar des de zero)
# 2. Compte a Cloudflare amb el domini demoasixcloud2025.cat gestionat
# 3. API Token de Cloudflare amb permisos Zone:DNS:Edit
```

### Configurar les variables d'entorn

```bash
# Copiar el fitxer d'exemple i editar-lo
cp .env.example .env
```

Edita el fitxer `.env` i configura els valors reals:

```bash
# .env
CF_DNS_API_TOKEN=el_teu_token_de_cloudflare_aqui
CF_ZONE_ID=el_teu_zone_id_aqui
```

> **Com obtenir el token de Cloudflare:**
> 1. Ves a [https://dash.cloudflare.com/profile/api-tokens](https://dash.cloudflare.com/profile/api-tokens)
> 2. Crea un nou token amb el template **Edit zone DNS**
> 3. Selecciona la zona `demoasixcloud2025.cat`
> 4. Copia el token generat al fitxer `.env`

> **Com obtenir el Zone ID:**
> 1. Ves al dashboard de Cloudflare per a la zona `demoasixcloud2025.cat`
> 2. A la columna dreta, trobaràs el **Zone ID**
> 3. Copia'l al fitxer `.env`

---

## Pas 1: Desplegar el laboratori (Etapa 2)

```bash
./lab.sh deploy 2
```

Comprova que els contenidors estan actius:

```bash
./lab.sh status
```

Hauries de veure 7 nodes: `switch-lan`, `router-frr`, `coredns`, `proxy`, `mail-alumnat`, `thunderbird1`, i el nou node `acme`.

> **Diferència amb l'Etapa 1:** La topologia `etapa2.yml` afegeix el node `acme` i
> configura DMS amb `SSL_TYPE: manual` i els paths dels certificats:
> - `SSL_CERT_PATH: /etc/ssl/mail/fullchain.pem`
> - `SSL_KEY_PATH: /etc/ssl/mail/key.pem`

---

## Pas 2: Configurar els comptes de correu

```bash
./lab.sh setup 2
```

Això crea els mateixos comptes que a l'Etapa 1 (`alumne1`, `alumne2`).

---

## Pas 3: Generar els certificats Let's Encrypt

### 3.1 Executar la generació de certificats

```bash
./lab.sh certs alumnat
```

Aquesta comanda:
1. Accedeix al contenidor `acme`
2. Utilitza `acme.sh` amb el mode DNS de Cloudflare
3. Crea un registre TXT `_acme-challenge.alumnat.demoasixcloud2025.cat` a Cloudflare
4. Let's Encrypt valida el registre TXT i emet el certificat
5. Els certificats es desen al directori `certs/alumnat/` del host

### 3.2 Verificar els certificats generats

```bash
ls -la certs/alumnat/
```

Hauries de veure, com a mínim:

```
fullchain.pem   # Certificat + cadena intermèdia
key.pem         # Clau privada
ca.pem          # Certificat de l'autoritat certificadora (CA)
cert.pem        # Certificat del domini
```

### 3.3 Inspeccionar el certificat

```bash
openssl x509 -in certs/alumnat/fullchain.pem -noout -text | head -30
```

Busca:
- **Issuer:** Hauria de dir `Let's Encrypt`
- **Subject CN:** `alumnat.demoasixcloud2025.cat` o `mail.alumnat.demoasixcloud2025.cat`
- **Validity:** Dates de validesa (90 dies des de l'emissió)

---

## Pas 4: Reiniciar el servidor de correu per carregar els certificats

Els certificats es munten automàticament al contenidor DMS via el bind mount
`certs/alumnat/ → /etc/ssl/mail/`. Però cal reiniciar els serveis perquè els carreguin:

```bash
# Reiniciar Postfix i Dovecot dins del contenidor
./lab.sh shell mail-alumnat
supervisorctl restart postfix
supervisorctl restart dovecot
exit
```

> **Alternativa:** Pots destruir i redesplegar tot el lab amb `./lab.sh destroy`
> seguit de `./lab.sh deploy 2`. Els certificats persisteixen al directori `certs/`.

---

## Pas 5: Verificar TLS amb openssl (SMTPS — port 465)

```bash
# Connexió TLS implícita al port 465 (SMTPS)
openssl s_client -connect 10.26.50.10:465
```

**Resultat esperat:**

```
CONNECTED(00000003)
depth=2 O = Digital Signature Trust Co., CN = DST Root CA X3
...
---
Certificate chain
 0 s:CN = mail.alumnat.demoasixcloud2025.cat
   i:C = US, O = Let's Encrypt, CN = R3
...
---
    Protocol  : TLSv1.3
    Cipher    : TLS_AES_256_GCM_SHA384
...
220 mail.alumnat.demoasixcloud2025.cat ESMTP
```

> **Clau:** El certificat és emès per Let's Encrypt (no és autosignat).
> La connexió utilitza TLSv1.2 o TLSv1.3.

---

## Pas 6: Verificar STARTTLS amb openssl (port 587)

```bash
# Connexió STARTTLS al port 587 (submission)
openssl s_client -starttls smtp -connect 10.26.50.10:587
```

**Diferència amb el pas anterior:**
- Al port 465, TLS s'estableix immediatament (TLS implícit).
- Al port 587, primer s'estableix una connexió en text pla, i després el client demana l'actualització a TLS amb la comanda `STARTTLS`.

Hauries de veure un handshake TLS similar al del port 465.

---

## Pas 7: Verificar IMAPS (port 993)

```bash
# Connexió TLS implícita al port 993 (IMAPS)
openssl s_client -connect 10.26.50.10:993
```

**Resultat esperat:**

```
* OK [CAPABILITY IMAP4rev1 ...] Dovecot ready.
```

Això confirma que Dovecot està servint IMAP sobre TLS al port 993.

---

## Pas 8: Reconfigurar Thunderbird amb connexions segures

### 8.1 Modificar el compte d'alumne1

1. A Thunderbird, ves a **Account Settings** (Configuració del compte)
2. Selecciona el compte `alumne1@alumnat.demoasixcloud2025.cat`
3. Modifica el **Servidor entrant (IMAP)**:

| Paràmetre | Valor anterior (Etapa 1) | Valor nou (Etapa 2) |
|-----------|--------------------------|---------------------|
| Port | 143 | **993** |
| Seguretat | Cap | **SSL/TLS** |
| Autenticació | Contrasenya normal | Contrasenya normal |

4. Modifica el **Servidor sortint (SMTP)**:

| Paràmetre | Valor anterior (Etapa 1) | Valor nou (Etapa 2) |
|-----------|--------------------------|---------------------|
| Port | 25 | **465** |
| Seguretat | Cap | **SSL/TLS** |
| Autenticació | Contrasenya normal | Contrasenya normal |

> **Alternativa:** Pots configurar el port 587 amb **STARTTLS** en lloc del port 465
> amb SSL/TLS implícit. Ambdues opcions són segures.

### 8.2 Repetir per al compte d'alumne2

Modifica els mateixos paràmetres per al segon compte.

---

## Pas 9: Enviar i rebre correus amb TLS

1. Envia un correu d'alumne1 a alumne2 amb el nou configuració TLS
2. Verifica la recepció a la safata d'entrada d'alumne2
3. Comprova que tot funciona correctament

> **Si la connexió falla:** Verifica que el certificat s'ha carregat correctament
> i que has reiniciat els serveis (Pas 4). Comprova els logs amb `./lab.sh logs mail-alumnat`.

---

## Pas 10: Capturar tràfic xifrat i comparar amb l'Etapa 1

### 10.1 Captura amb TLS (IMAPS, port 993)

```bash
./pcap.sh mail-alumnat eth1 "port 993"
```

Mentrestant, consulta la safata d'entrada des de Thunderbird.

Prem `Ctrl+C` per aturar la captura.

### 10.2 Analitzar la captura

```bash
wireshark mail-alumnat_eth1_*.pcapng
```

**Què hauries de veure:**
- Handshake TLS (Client Hello, Server Hello, Certificate, Key Exchange)
- Dades xifrades (**Application Data**): el contingut és il·legible
- **Cap credencial visible** en text pla

### 10.3 Comparació amb l'Etapa 1

| Aspecte | Etapa 1 (sense TLS) | Etapa 2 (amb TLS) |
|---------|---------------------|---------------------|
| Credencials | Visibles en clar | Xifrades |
| Contingut del correu | Visible en clar | Xifrat |
| Capçaleres SMTP | Visibles | Xifrades |
| Handshake TLS | No existeix | Visible (però les dades no) |
| Port IMAP | 143 | 993 |
| Port SMTP | 25 | 465 o 587+STARTTLS |

---

## Pas 11: Aturar el laboratori

```bash
./lab.sh destroy
```

> **Nota:** Els certificats al directori `certs/` persisteixen després de destruir
> el lab. No cal regenerar-los cada vegada.

---

## Resum de l'Etapa 2

| Aspecte | Valor |
|---------|-------|
| Protocol d'enviament | SMTPS (port 465) o SMTP+STARTTLS (port 587) |
| Protocol de recepció | IMAPS (port 993) |
| Xifrat | TLS 1.2/1.3 amb certificat Let's Encrypt |
| Validació ACME | DNS-01 via Cloudflare API |
| Fitxers de certificat | `certs/alumnat/{fullchain.pem, key.pem}` |
| Eina ACME | `acme.sh` dins del contenidor `acme` |
| SSL_TYPE a DMS | `manual` |
| Node nou | `acme` (10.26.50.250) |
| Topologia | `topologies/etapa2.yml` |

### Ports abans i després de TLS

| Servei | Sense TLS (Etapa 1) | Amb TLS (Etapa 2) |
|--------|---------------------|--------------------|
| SMTP (entre servidors) | 25 | 25 (amb STARTTLS oportunista) |
| SMTP (submissió client) | 25 | 587 (STARTTLS) o 465 (TLS implícit) |
| IMAP | 143 | 993 (TLS implícit) |

---

## Observacions importants

- **STARTTLS vs. TLS implícit:** STARTTLS és una extensió del protocol que permet actualitzar una connexió en text pla a TLS. El TLS implícit estableix la connexió TLS des del primer moment. Ambdós proporcionen el mateix nivell de xifrat un cop establerta la connexió, però el TLS implícit és preferible perquè no és vulnerable a atacs de *downgrade* (on un atacant impedeix l'actualització a TLS).

- **Validació DNS-01 vs. HTTP-01:** La validació DNS-01 demostra el control del domini creant un registre TXT al DNS. La validació HTTP-01 requereix que el servidor web sigui accessible des d'Internet. Per a servidors de correu interns, la validació DNS és l'única opció viable perquè el servidor no necessita ser accessible des d'Internet.

- **Certificats Let's Encrypt:** Són gratuïts i reconeguts per tots els navegadors i clients de correu. Tenen una validesa de 90 dies i s'han de renovar periòdicament. Let's Encrypt no emet certificats wildcard sense validació DNS.

- **El port 25 segueix actiu:** Fins i tot amb TLS configurat, el port 25 segueix acceptant connexions per a la comunicació entre servidors (MTA-to-MTA). Això és necessari perquè no tots els servidors de correu d'Internet suporten TLS. El STARTTLS al port 25 és *oportunista*: s'utilitza si ambdós servidors el suporten, però no es requereix.

- **Seguretat de la clau privada:** El fitxer `key.pem` conté la clau privada del certificat. Si un atacant obté aquesta clau, pot suplanta la identitat del servidor. Cal protegir-la adequadament (permisos 600, no compartir-la).

---

## Preguntes de reflexió — Etapa 2

1. Quina diferència hi ha entre STARTTLS i TLS implícit? En quins ports s'utilitza cadascun per a SMTP i IMAP? Per què el TLS implícit es considera més segur que STARTTLS?

2. Explica com funciona la validació DNS-01 d'ACME. Per què és necessària per a servidors de correu que no són accessibles des d'Internet? Quina alternativa existeix (HTTP-01) i per què no és viable en aquest cas?

3. Per què és necessari un API Token de Cloudflare per generar els certificats? Quins permisos específics necessita el token? Quins riscos comporta exposar aquest token?

4. Descriu la cadena de certificats (certificate chain): què conté `cert.pem`, `fullchain.pem`, `key.pem` i `ca.pem`? Per què el servidor necessita enviar la cadena completa i no només el certificat del domini?

5. Quina diferència hi ha entre els ports 25, 587 i 465 en el context de SMTP? Quin s'utilitza per a la comunicació entre servidors (relay) i quin per a la submissió de correus dels clients?

6. Què passa si un certificat Let's Encrypt caduca i no es renova? Com afecta això als clients de correu? Quina és la validesa estàndard d'un certificat Let's Encrypt?

7. Què és Let's Encrypt i quina funció compleix com a CA (Autoritat Certificadora)? Quines limitacions té respecte a CAs comercials? Pot emetre certificats per a dominis `.local` o IP privades?

8. Per què el port 25 segueix acceptant connexions sense requerir TLS obligatori, fins i tot quan el servidor té certificats configurats? Què és el STARTTLS oportunista?

9. Com pots verificar que un servidor de correu utilitza un certificat vàlid amb la comanda `openssl s_client`? Quines dades del certificat pots inspeccionar (emissor, data de caducitat, algorisme)?

10. Quina diferència hi ha entre un certificat autosignat (self-signed) i un certificat emès per una CA reconeguda com Let's Encrypt? Quins avantatges i inconvenients té cadascun en un entorn educatiu vs. producció?
