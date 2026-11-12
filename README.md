# Laboratori de Servidors de Correu Electronic 2026

Laboratori educatiu de servidors de correu electronic desplegat amb **Containerlab**, pensat per a alumnat d'**ASIX** (Administracio de Sistemes Informatics en Xarxa). Treballa amb 3 servidors de correu (docker-mailserver, Stalwart, Mailcow) i 3 subdominis del domini `demoasixcloud2025.cat`.

---

## Prerequisits

| Requisit | Descripcio |
|----------|------------|
| [Docker](https://docs.docker.com/engine/install/) | Engine + CLI per a contenidors |
| [Containerlab](https://containerlab.dev/install/) | Orquestrador de topologies de xarxa |
| Compte [Cloudflare](https://dash.cloudflare.com/) | Per a validacio DNS de certificats Let's Encrypt |

Copia el fitxer `.env.example` a `.env` i configura les variables:

```bash
cp .env.example .env
# Edita .env amb el teu CF_DNS_API_TOKEN i CF_ZONE_ID
```

---

## Inici rapid

```bash
# 1. Construir les imatges Docker personalitzades
./lab.sh build

# 2. Desplegar una etapa (ex: etapa 1)
./lab.sh deploy 1

# 3. Executar configuracio post-desplegament
./lab.sh setup 1
```

---

## Etapes

El laboratori esta organitzat en 6 etapes progressives:

| Etapa | Descripcio | Nodes nous |
|:-----:|------------|------------|
| 1 | Correu basic amb DMS (sense TLS) | switch, router, coredns, proxy, mail-alumnat, thunderbird1 |
| 2 | Certificats Let's Encrypt (TLS) | acme |
| 3 | Enviament via terminal (swaks) | client-swaks |
| 4 | DKIM, DMARC, SPF | (cap node nou, nomes configuracio) |
| 5 | Stalwart + Roundcube | mail-professorat, roundcube, thunderbird2 |
| 6 | Mailcow | mail-alumni (multi-contenidor) |

Cada etapa te les seves instruccions a `etapaN/instruccions-etapaN.md`.

---

## Estructura del projecte

```
007-mailserver-lab/
├── lab.sh                          # Script central de gestio del lab
├── pcap.sh                         # Script de captura de paquets
├── .env.example                    # Variables d'entorn (Cloudflare)
├── topologies/
│   ├── etapa1.yml                  # Topologia Containerlab per etapa
│   ├── etapa2.yml
│   ├── etapa3.yml
│   ├── etapa4.yml
│   ├── etapa5.yml
│   └── etapa6.yml
├── configs/
│   ├── coredns/                    # Corefile + zones DNS
│   │   ├── Corefile
│   │   └── zones/
│   ├── dms/                        # docker-mailserver (etapa 1 i 4)
│   │   ├── etapa1/
│   │   └── etapa4/
│   ├── frr/                        # FRRouting (router)
│   ├── nginx/                      # Proxy invers (etapa 1, 5, 6)
│   ├── stalwart/                   # Stalwart (etapa 5)
│   ├── mailcow/                    # Mailcow (etapa 6)
│   └── thunderbird/                # Configuracio Thunderbird
├── scripts/
│   ├── acme-certs.sh               # Generacio de certificats
│   ├── client-swaks-init.sh        # Inicialitzacio client SMTP
│   ├── client-thunderbird-init.sh  # Inicialitzacio Thunderbird
│   ├── dns-init.sh                 # Inicialitzacio CoreDNS
│   ├── proxy-init.sh               # Inicialitzacio Nginx
│   ├── router-init.sh              # Inicialitzacio router FRR
│   ├── server-dms-init.sh          # Inicialitzacio DMS
│   ├── server-stalwart-init.sh     # Inicialitzacio Stalwart
│   └── switch-init.sh              # Inicialitzacio switch L2
├── base/
│   └── docker/
│       ├── switch/                 # Dockerfile switch L2
│       ├── client-swaks/           # Dockerfile client SMTP
│       └── acme/                   # Dockerfile ACME
├── etapa1/
│   └── instruccions-etapa1.md
├── etapa2/
│   └── instruccions-etapa2.md
├── etapa3/
│   └── instruccions-etapa3.md
├── etapa4/
│   └── instruccions-etapa4.md
├── etapa5/
│   └── instruccions-etapa5.md
├── etapa6/
│   └── instruccions-etapa6.md
├── activitats/                     # Activitats extenses
└── presentation/
    └── reveal.js/                  # Presentacio reveal.js
```

---

## Xarxa

**Rang:** `10.26.50.0/24`

| Node | IP | Rol |
|------|----|-----|
| switch-lan | — (L2 bridge) | Switch de capa 2 |
| router-frr | 10.26.50.1 | Gateway / router FRRouting |
| coredns | 10.26.50.2 | DNS intern |
| proxy | 10.26.50.3 | Proxy invers Nginx |
| mail-alumnat | 10.26.50.10 | docker-mailserver (DMS) |
| mail-professorat | 10.26.50.20 | Stalwart |
| mail-alumni | 10.26.50.30 | Mailcow (multi-contenidor) |
| thunderbird1 | 10.26.50.100 | Client de correu (noVNC) |
| thunderbird2 | 10.26.50.101 | Client de correu (noVNC) |
| roundcube | 10.26.50.102 | Webmail Roundcube |
| client-swaks | 10.26.50.200 | Client SMTP per terminal |
| acme | 10.26.50.250 | Generacio de certificats |

**Xarxa de gestio (management):** `172.20.26.0/24`

---

## Dominis

| Subdomini | Servidor | IP |
|-----------|----------|----|
| `alumnat.demoasixcloud2025.cat` | docker-mailserver | 10.26.50.10 |
| `professorat.demoasixcloud2025.cat` | Stalwart | 10.26.50.20 |
| `alumni.demoasixcloud2025.cat` | Mailcow | 10.26.50.30 |

Resolucio interna via CoreDNS. Resolucio publica (MX, SPF, DKIM, DMARC) via Cloudflare.

---

## Comptes predefinits

| Compte | Contrasenya |
|--------|-------------|
| `alumne1@alumnat.demoasixcloud2025.cat` | `Alumne1.2025` |
| `alumne2@alumnat.demoasixcloud2025.cat` | `Alumne2.2025` |
| `profe1@professorat.demoasixcloud2025.cat` | `Profe1.2025` |
| `profe2@professorat.demoasixcloud2025.cat` | `Profe2.2025` |
| `exalumne1@alumni.demoasixcloud2025.cat` | `Exalumne1.2025` |

---

## Ports de referencia

| Port | Protocol | Descripcio |
|------|----------|------------|
| 25 | SMTP | Recepcio de correu (MTA a MTA) |
| 465 | SMTPS | Enviament amb TLS implicit |
| 587 | Submission | Enviament amb STARTTLS |
| 143 | IMAP | Lectura de correu (sense xifrar) |
| 993 | IMAPS | Lectura de correu (TLS) |
| 110 | POP3 | Descarrega de correu (sense xifrar) |
| 995 | POP3S | Descarrega de correu (TLS) |
| 80 | HTTP | Webmail / proxy |
| 443 | HTTPS | Webmail / proxy (TLS) |
| 5800 | HTTP | Thunderbird via noVNC |

---

## Referencia de comandes

### lab.sh

```bash
./lab.sh build [target]       # Construir imatges (all, mail-switch, mail-client-swaks, mail-acme)
./lab.sh deploy <etapa>       # Desplegar etapa (1-6)
./lab.sh setup <etapa>        # Configuracio post-desplegament
./lab.sh certs [dominis]      # Generar certificats Let's Encrypt
./lab.sh destroy              # Destruir el laboratori
./lab.sh status               # Mostrar estat del laboratori
./lab.sh shell <node>         # Obrir shell a un node
./lab.sh logs <node>          # Veure logs d'un node
./lab.sh help                 # Mostrar ajuda
```

### pcap.sh

```bash
./pcap.sh <node> [interficie] [filtre]

# Exemples
./pcap.sh mail-alumnat                                    # Tot el trafic a eth1
./pcap.sh mail-alumnat eth1 "port 25"                     # Nomes SMTP
./pcap.sh mail-alumnat eth1 "port 993"                    # Nomes IMAPS
./pcap.sh mail-alumnat eth1 "port 25 or port 587"         # SMTP + Submission
```

Les captures es desen com a fitxers `.pcapng` i es poden obrir amb Wireshark.

---

## Resolucio de problemes

### El contenidor no arrenca o no te IP

```bash
# Verificar estat dels contenidors
./lab.sh status

# Comprovar logs del node
./lab.sh logs <node>

# Comprovar IP assignada
docker exec clab-mailserver-lab-<node> ip addr show eth1
```

### CoreDNS no resol noms

CoreDNS es un contenidor scratch (sense shell). La xarxa es configura via `nsenter` durant el desplegament. Si no resol:

```bash
# Reconfigurar xarxa manualment
sudo nsenter -t $(docker inspect -f '{{.State.Pid}}' clab-mailserver-lab-coredns) -n ip addr show
```

### DMS no accepta connexions

```bash
# Verificar que Postfix esta actiu
docker exec clab-mailserver-lab-mail-alumnat supervisorctl status

# Comprovar comptes creats
docker exec clab-mailserver-lab-mail-alumnat setup email list
```

### Certificats Let's Encrypt no es generen

1. Verifica que el fitxer `.env` conte un `CF_DNS_API_TOKEN` valid.
2. El contenidor `acme` ha d'estar desplegat (etapa >= 2).
3. Comprova la connexio a Internet del contenidor ACME.

```bash
docker exec clab-mailserver-lab-acme ping -c 2 acme-v02.api.letsencrypt.org
```

### Thunderbird no connecta al servidor

1. Accedeix via navegador: `http://localhost:5800` (o la IP del node Thunderbird).
2. Configura el servidor entrant (IMAP) i sortint (SMTP) amb les IPs de la xarxa interna.
3. Si no hi ha TLS (etapa 1), desactiva la seguretat de la connexio a Thunderbird.

### No es pot accedir als serveis des del host

La xarxa `10.26.50.0/24` es interna dels contenidors. Utilitza el proxy Nginx (10.26.50.3) o accedeix via la xarxa de gestio `172.20.26.0/24`.
