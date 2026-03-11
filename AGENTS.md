# AGENTS.md — Context per a assistents IA

## Descripció del projecte

Laboratori educatiu de servidors de correu electrònic desplegat amb **Containerlab**.
Pensat per a alumnat d'ASIX (Administració de Sistemes Informàtics en Xarxa).
Treballa amb 3 servidors de correu (docker-mailserver, Stalwart, Mailcow) i 3 subdominis.

## Comandes habituals

```bash
# Construir imatges Docker personalitzades
./lab.sh build

# Desplegar una etapa concreta
./lab.sh deploy 1

# Executar setup post-desplegament
./lab.sh setup 1

# Veure estat del lab
./lab.sh status

# Obrir shell a un node
./lab.sh shell mail-alumnat

# Veure logs d'un node
./lab.sh logs mail-alumnat

# Destruir el lab
./lab.sh destroy

# Generar certificats Let's Encrypt
./lab.sh certs

# Capturar paquets
./pcap.sh mail-alumnat eth1
```

## Arquitectura per etapes

| Etapa | Descripció | Nodes nous |
|-------|-----------|------------|
| 1 | Correu bàsic amb DMS (sense TLS) | switch, router, coredns, proxy, mail-alumnat, thunderbird1 |
| 2 | Certificats Let's Encrypt (TLS) | acme |
| 3 | Enviament via terminal (swaks) | client-swaks |
| 4 | DKIM, DMARC, SPF | (cap node nou, configuració) |
| 5 | Stalwart + Roundcube | mail-professorat, roundcube, thunderbird2 |
| 6 | Mailcow | mail-alumni (multi-contenidor) |

## Xarxa

- **Rang:** 10.26.50.0/24
- **Gateway:** 10.26.50.1 (router-frr)
- **DNS intern:** 10.26.50.2 (CoreDNS)
- **Proxy:** 10.26.50.3 (Nginx)
- **DMS:** 10.26.50.10 (alumnat.demoasixcloud2025.cat)
- **Stalwart:** 10.26.50.20 (professorat.demoasixcloud2025.cat)
- **Mailcow:** 10.26.50.30 (alumni.demoasixcloud2025.cat)
- **Thunderbird 1:** 10.26.50.100
- **Thunderbird 2:** 10.26.50.101
- **Roundcube:** 10.26.50.102
- **Client swaks:** 10.26.50.200
- **ACME:** 10.26.50.250
- **Management containerlab:** 172.20.26.0/24

## Dominis

- `alumnat.demoasixcloud2025.cat` → docker-mailserver (10.26.50.10)
- `professorat.demoasixcloud2025.cat` → Stalwart (10.26.50.20)
- `alumni.demoasixcloud2025.cat` → Mailcow (10.26.50.30)

## Comptes predefinits

- `alumne1@alumnat.demoasixcloud2025.cat` / password: `Alumne1.2025`
- `alumne2@alumnat.demoasixcloud2025.cat` / password: `Alumne2.2025`
- `profe1@professorat.demoasixcloud2025.cat` / password: `Profe1.2025`
- `profe2@professorat.demoasixcloud2025.cat` / password: `Profe2.2025`
- `exalumne1@alumni.demoasixcloud2025.cat` / password: `Exalumne1.2025`

## Fitxers clau

- `lab.sh` — Script central de gestió del lab
- `topologies/etapaN.yml` — Topologies Containerlab (una per etapa)
- `configs/` — Configuracions de tots els serveis
- `scripts/` — Scripts d'inicialització dels contenidors
- `etapaN/instruccions-etapaN.md` — Instruccions pas a pas per etapa
- `activitats/activitats-mailserver.md` — Activitats extenses
- `presentation/index.html` — Presentació reveal.js

## Convencions de codi

### Bash
- `set -euo pipefail` al script principal (lab.sh)
- `set -e` als scripts d'inicialització
- Variables en UPPER_SNAKE_CASE
- Funcions amb prefix `_` per a funcions internes
- Indentació: 4 espais
- Comentaris de secció: `# --- Descripció ---`

### YAML (Containerlab)
- Indentació: 2 espais
- Comentaris de secció per node: `# --- NOM DEL NODE ---`
- Noms de nodes en minúscules amb guions

### Documentació
- Idioma: Català
- Format: Markdown (GitHub-flavored)
- Estructura instruccions: Objectiu → Diagrama → Prerequisits → Passos → Resum → Preguntes

## Notes tècniques importants

- El switch és un contenidor Linux amb bridge-utils (NO un linux bridge del host)
- Les IPs s'assignen via `exec` post-startup als contenidors
- Thunderbird usa jlesage/thunderbird (ja inclou noVNC)
- Mailcow és multi-contenidor (es gestiona com a conjunt dins containerlab)
- Certificats reals de Let's Encrypt amb validació DNS via Cloudflare
- DNS intern (CoreDNS) per resolució entre contenidors
- DNS públic (Cloudflare) per registres MX, SPF, DKIM, DMARC
- Els dominis NO es comuniquen entre ells (aïllats)
