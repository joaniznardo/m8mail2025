#!/bin/bash
set -euo pipefail

# ============================================================================
# lab.sh — Script central de gestió del laboratori de servidors de correu
# ============================================================================
# Ús: ./lab.sh <comanda> [arguments]
# Comandes: build, deploy, setup, destroy, status, shell, logs, certs, help
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOPOLOGIES_DIR="${SCRIPT_DIR}/topologies"
LAB_NAME="mailserver-lab"
MGMT_NETWORK="mailserver-mgmt"

# --- Colors i logging ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# --- Funcions internes ---

_check_prerequisites() {
    local missing=0
    for cmd in docker containerlab; do
        if ! command -v "$cmd" &> /dev/null; then
            error "$cmd no està instal·lat"
            missing=1
        fi
    done
    if [ $missing -eq 1 ]; then
        error "Instal·la els prerequisits i torna-ho a provar"
        exit 1
    fi
    ok "Prerequisits verificats (docker, containerlab)"
}

_required_images_for_stage() {
    local stage=$1
    case $stage in
        1) echo "mail-switch" ;;
        2) echo "mail-switch mail-acme" ;;
        3) echo "mail-switch mail-acme mail-client-swaks" ;;
        4) echo "mail-switch mail-acme mail-client-swaks" ;;
        5) echo "mail-switch mail-acme mail-client-swaks" ;;
        6) echo "mail-switch mail-acme mail-client-swaks" ;;
        *) error "Etapa desconeguda: $stage"; exit 1 ;;
    esac
}

_image_exists() {
    docker image inspect "$1:latest" &> /dev/null
}

_build_image() {
    local name=$1
    local context=""

    case $name in
        mail-switch)
            context="${SCRIPT_DIR}/base/docker/switch"
            ;;
        mail-client-swaks)
            context="${SCRIPT_DIR}/base/docker/client-swaks"
            ;;
        mail-acme)
            context="${SCRIPT_DIR}/base/docker/acme"
            ;;
        *)
            error "Imatge desconeguda: $name"
            return 1
            ;;
    esac

    info "Construint imatge ${name}:latest des de ${context}..."
    docker build -t "${name}:latest" "${context}"
    ok "Imatge ${name}:latest construïda"
}

_ensure_images() {
    local stage=$1
    local images
    images=$(_required_images_for_stage "$stage")

    for img in $images; do
        if ! _image_exists "$img"; then
            warn "Imatge $img no trobada, construint..."
            _build_image "$img"
        fi
    done
}

_load_env() {
    if [ -f "${SCRIPT_DIR}/.env" ]; then
        # shellcheck disable=SC2046
        export $(grep -v '^#' "${SCRIPT_DIR}/.env" | grep -v '^$' | xargs)
        ok "Variables d'entorn carregades des de .env"
    else
        warn "Fitxer .env no trobat. Copia .env.example a .env i configura'l."
    fi
}

_get_topology_file() {
    local stage=$1
    local file="${TOPOLOGIES_DIR}/etapa${stage}.yml"
    if [ ! -f "$file" ]; then
        error "Topologia no trobada: $file"
        exit 1
    fi
    echo "$file"
}

_configure_node_network() {
    # Configura la xarxa d'un node que no té shell o no té ip (ex: coredns, stalwart, roundcube)
    local container=$1
    local ip=$2
    local gateway=$3
    local dns=${4:-""}

    local pid
    pid=$(docker inspect -f '{{.State.Pid}}' "$container" 2>/dev/null)
    if [ -n "$pid" ] && [ "$pid" != "0" ]; then
        sudo nsenter -t "$pid" -n ip addr add "${ip}/24" dev eth1 2>/dev/null || true
        sudo nsenter -t "$pid" -n ip link set eth1 up 2>/dev/null || true
        sudo nsenter -t "$pid" -n ip route add default via "$gateway" 2>/dev/null || true
        if [ -n "$dns" ]; then
            # Configurar DNS resolver dins del contenidor
            # Usem nsenter amb mount namespace per escriure resolv.conf
            sudo nsenter -t "$pid" -m -n sh -c "echo 'nameserver ${dns}' > /etc/resolv.conf" 2>/dev/null || true
        fi
    fi
}

_post_deploy_network() {
    local stage=$1
    info "Configurant xarxa post-desplegament per a l'etapa ${stage}..."

    # CoreDNS és scratch-based (sense shell), cal nsenter
    local coredns_container="clab-${LAB_NAME}-coredns"
    if docker ps -q -f "name=${coredns_container}" | grep -q .; then
        info "Configurant xarxa de CoreDNS via nsenter..."
        _configure_node_network "$coredns_container" "10.26.50.2" "10.26.50.1"
        ok "CoreDNS configurat: 10.26.50.2/24"
    fi

    # A partir de l'etapa 5: Stalwart i Roundcube no tenen la comanda ip
    if [ "$stage" -ge 5 ]; then
        # Stalwart (mail-professorat)
        local stalwart_container="clab-${LAB_NAME}-mail-professorat"
        if docker ps -q -f "name=${stalwart_container}" | grep -q .; then
            info "Configurant xarxa de Stalwart via nsenter..."
            _configure_node_network "$stalwart_container" "10.26.50.20" "10.26.50.1" "10.26.50.2"
            ok "Stalwart configurat: 10.26.50.20/24"
        fi

        # Roundcube
        local roundcube_container="clab-${LAB_NAME}-roundcube"
        if docker ps -q -f "name=${roundcube_container}" | grep -q .; then
            info "Configurant xarxa de Roundcube via nsenter..."
            _configure_node_network "$roundcube_container" "10.26.50.102" "10.26.50.1" "10.26.50.2"
            ok "Roundcube configurat: 10.26.50.102/24"
        fi
    fi

    # Etapa 6: mail-alumni (ubuntu:24.04 minimal no té iproute2)
    if [ "$stage" -ge 6 ]; then
        local alumni_container="clab-${LAB_NAME}-mail-alumni"
        if docker ps -q -f "name=${alumni_container}" | grep -q .; then
            info "Configurant xarxa de mail-alumni via nsenter..."
            _configure_node_network "$alumni_container" "10.26.50.30" "10.26.50.1" "10.26.50.2"
            ok "mail-alumni configurat: 10.26.50.30/24"
        fi
    fi
}

_setup_dms_accounts() {
    local container="clab-${LAB_NAME}-mail-alumnat"
    info "Configurant comptes de docker-mailserver..."

    # Esperar que DMS estigui llest
    for i in $(seq 1 30); do
        if docker exec "$container" supervisorctl status postfix 2>/dev/null | grep -q RUNNING; then
            break
        fi
        info "Esperant DMS... (${i}/30)"
        sleep 5
    done

    # Crear comptes (si no existeixen)
    docker exec "$container" setup email add alumne1@alumnat.demoasixcloud2025.cat 'Alumne1.2025' 2>/dev/null || true
    docker exec "$container" setup email add alumne2@alumnat.demoasixcloud2025.cat 'Alumne2.2025' 2>/dev/null || true
    ok "Comptes DMS creats"
}

_setup_dkim() {
    local container="clab-${LAB_NAME}-mail-alumnat"
    info "Configurant DKIM per a alumnat.demoasixcloud2025.cat..."

    # Les claus DKIM ja estan pre-generades a configs/dms/etapa4/rspamd/dkim/
    # i la configuració de Rspamd a configs/dms/etapa4/rspamd/override.d/dkim_signing.conf
    # NO executem 'setup config dkim' perquè sobreescriu les claus i el config pre-generats

    # Afegir automàticament els registres SPF, DKIM i DMARC a CoreDNS
    # (cal fer-ho ABANS de reiniciar Rspamd perquè check_pubkey=true)
    _setup_dns_dkim_records

    # Reiniciar Rspamd per assegurar que carrega la configuració i claus correctes
    info "Reiniciant Rspamd per carregar la configuració DKIM..."
    docker exec "$container" supervisorctl restart rspamd 2>/dev/null || true
    sleep 3
    ok "DKIM configurat i Rspamd reiniciat."
}

_setup_dns_dkim_records() {
    local zone_file="${SCRIPT_DIR}/configs/coredns/zones/db.demoasixcloud2025.cat"
    local dkim_public_key_file="${SCRIPT_DIR}/configs/dms/etapa4/rspamd/dkim/rsa-2048-mail-alumnat.demoasixcloud2025.cat.public.dns.txt"
    local domain="alumnat"
    local selector="mail"

    info "Actualitzant registres DNS (SPF, DKIM, DMARC) a CoreDNS..."

    # Comprovar que el fitxer de zona existeix
    if [ ! -f "$zone_file" ]; then
        error "Fitxer de zona no trobat: $zone_file"
        return 1
    fi

    # Comprovar que la clau pública DKIM existeix
    if [ ! -f "$dkim_public_key_file" ]; then
        error "Clau pública DKIM no trobada: $dkim_public_key_file"
        info "Assegura't que les claus DKIM estan generades a configs/dms/etapa4/rspamd/dkim/"
        return 1
    fi

    # Llegir la clau pública DKIM (una sola línia, sense espais finals)
    local dkim_value
    dkim_value=$(tr -d '\n\r' < "$dkim_public_key_file" | sed 's/[[:space:]]*$//')

    # Dividir el valor DKIM en fragments de 255 caràcters per complir el límit DNS TXT
    # CoreDNS accepta format multi-string amb parèntesis: ( "part1" "part2" )
    local dkim_txt_record
    local dkim_len=${#dkim_value}
    if [ "$dkim_len" -gt 255 ]; then
        local parts=""
        local pos=0
        local chunk_size=255
        while [ $pos -lt "$dkim_len" ]; do
            local chunk="${dkim_value:$pos:$chunk_size}"
            if [ -z "$parts" ]; then
                parts="\"${chunk}\""
            else
                parts="${parts} \"${chunk}\""
            fi
            pos=$((pos + chunk_size))
        done
        dkim_txt_record="${selector}._domainkey.${domain} IN  TXT     ( ${parts} )"
    else
        dkim_txt_record="${selector}._domainkey.${domain} IN  TXT     \"${dkim_value}\""
    fi

    # Comprovar si els registres ja existeixen (evitar duplicats)
    if grep -q "${selector}._domainkey.${domain}" "$zone_file" 2>/dev/null; then
        warn "Registres SPF/DKIM/DMARC ja presents a la zona DNS. S'actualitzaran."
        # Eliminar la secció existent de registres SPF/DKIM/DMARC
        local tmp_file
        tmp_file=$(mktemp)
        # Eliminar des de la línia de comentari fins a la pròxima línia buida (o final de fitxer)
        awk '/^; --- Registres SPF, DKIM i DMARC/{skip=1; next} /^$/{if(skip){skip=0; next}} !skip' "$zone_file" > "$tmp_file"
        # Eliminar línies buides al final del fitxer
        sed -i -e :a -e '/^[[:space:]]*$/{ $d; N; ba' -e '}' "$tmp_file"
        cp "$tmp_file" "$zone_file"
        rm -f "$tmp_file"
    fi

    # Incrementar el serial del SOA (format YYYYMMDDNN)
    local current_serial
    current_serial=$(grep -oP '\d{10}(?=\s*;\s*Serial)' "$zone_file")
    if [ -n "$current_serial" ]; then
        local today
        today=$(date +%Y%m%d)
        local serial_date="${current_serial:0:8}"
        local serial_num="${current_serial:8:2}"
        if [ "$serial_date" = "$today" ]; then
            serial_num=$(printf "%02d" $(( 10#$serial_num + 1 )))
        else
            serial_num="01"
        fi
        local new_serial="${today}${serial_num}"
        sed -i "s/${current_serial}\(\s*;\s*Serial\)/${new_serial}\1/" "$zone_file"
        info "Serial de la zona actualitzat: ${current_serial} -> ${new_serial}"
    fi

    # Afegir els registres SPF, DKIM i DMARC al final del fitxer de zona
    {
        echo ""
        echo "; --- Registres SPF, DKIM i DMARC per a ${domain} ---"
        echo "${domain}                       IN  TXT     \"v=spf1 ip4:10.26.50.0/24 mx ~all\""
        echo "${dkim_txt_record}"
        echo "_dmarc.${domain}                IN  TXT     \"v=DMARC1; p=none; rua=mailto:postmaster@${domain}.demoasixcloud2025.cat\""
    } >> "$zone_file"

    ok "Registres DNS afegits a la zona CoreDNS:"
    ok "  SPF:   ${domain}.demoasixcloud2025.cat TXT \"v=spf1 ip4:10.26.50.0/24 mx ~all\""
    ok "  DKIM:  ${selector}._domainkey.${domain}.demoasixcloud2025.cat TXT \"v=DKIM1; k=rsa; p=...\""
    ok "  DMARC: _dmarc.${domain}.demoasixcloud2025.cat TXT \"v=DMARC1; p=none; ...\""

    # CoreDNS recarrega automàticament la zona gràcies al plugin "reload 5s" al Corefile.
    # NO reiniciem el contenidor perquè docker restart trenca els enllaços de containerlab.
    local coredns_container="clab-${LAB_NAME}-coredns"
    if docker ps -q -f "name=${coredns_container}" | grep -q .; then
        info "CoreDNS recarregarà la zona automàticament en uns segons (reload plugin)..."
        sleep 6
        ok "Registres DNS actius a CoreDNS"
    else
        info "CoreDNS no actiu. Els registres s'aplicaran al pròxim desplegament."
    fi
}

_setup_stalwart() {
    local setup_script="${SCRIPT_DIR}/configs/stalwart/etapa5/setup-stalwart.sh"
    local swaks_container="clab-${LAB_NAME}-client-swaks"

    if [ ! -f "$setup_script" ]; then
        warn "Script de setup de Stalwart no trobat: $setup_script"
        return
    fi

    info "Configurant Stalwart (des de ${swaks_container})..."

    # Copiar l'script dins del contenidor client-swaks i executar-lo allà
    # perquè el host no té ruta a la xarxa del lab (10.26.50.0/24)
    docker cp "$setup_script" "${swaks_container}:/tmp/setup-stalwart.sh"
    docker exec "${swaks_container}" bash /tmp/setup-stalwart.sh

    # Obtenir els registres DNS generats per Stalwart i afegir-los a CoreDNS
    _setup_dns_stalwart_records
}

_setup_dns_stalwart_records() {
    local zone_file="${SCRIPT_DIR}/configs/coredns/zones/db.demoasixcloud2025.cat"
    local swaks_container="clab-${LAB_NAME}-client-swaks"
    local domain="professorat"
    local fqdn="professorat.demoasixcloud2025.cat"

    info "Afegint registres SPF/DKIM/DMARC de ${fqdn} a CoreDNS..."

    # Llegir el fitxer JSON de registres DNS generat per setup-stalwart.sh
    local dns_json
    dns_json=$(docker exec "${swaks_container}" cat /tmp/stalwart-dns-records.json 2>/dev/null || true)

    if [ -z "$dns_json" ]; then
        warn "No s'han trobat registres DNS de Stalwart. S'afegiran registres SPF i DMARC bàsics."
        local dkim_record=""
    else
        # Extreure el registre DKIM TXT (conté _domainkey)
        # Format JSON: {"data":[{"type":"TXT","name":"selector._domainkey.domain.","content":"v=DKIM1; ..."},...]}
        local dkim_record
        dkim_record=$(echo "$dns_json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for rec in data.get('data', []):
    if rec.get('type') == 'TXT' and '_domainkey' in rec.get('name', ''):
        name = rec['name'].rstrip('.')
        # Convertir FQDN a relatiu dins la zona demoasixcloud2025.cat
        name = name.replace('.demoasixcloud2025.cat', '')
        content = rec['content']
        # Dividir en fragments de 255 caràcters si cal
        if len(content) > 255:
            parts = []
            for i in range(0, len(content), 255):
                parts.append('\"' + content[i:i+255] + '\"')
            print(f'{name:<40} IN  TXT     ( {\" \".join(parts)} )')
        else:
            print(f'{name:<40} IN  TXT     \"{content}\"')
        break
" 2>/dev/null || true)
    fi

    # Comprovar si els registres ja existeixen (evitar duplicats)
    if grep -q "_domainkey.${domain}" "$zone_file" 2>/dev/null || grep -q "; --- Registres SPF, DKIM i DMARC per a ${domain}" "$zone_file" 2>/dev/null; then
        warn "Registres SPF/DKIM/DMARC de ${domain} ja presents a la zona DNS. S'actualitzaran."
        local tmp_file
        tmp_file=$(mktemp)
        awk "/^; --- Registres SPF, DKIM i DMARC per a ${domain}/{skip=1; next} /^\$/{if(skip){skip=0; next}} !skip" "$zone_file" > "$tmp_file"
        sed -i -e :a -e '/^[[:space:]]*$/{ $d; N; ba' -e '}' "$tmp_file"
        cp "$tmp_file" "$zone_file"
        rm -f "$tmp_file"
    fi

    # Incrementar el serial del SOA
    local current_serial
    current_serial=$(grep -oP '\d{10}(?=\s*;\s*Serial)' "$zone_file")
    if [ -n "$current_serial" ]; then
        local today
        today=$(date +%Y%m%d)
        local serial_date="${current_serial:0:8}"
        local serial_num="${current_serial:8:2}"
        if [ "$serial_date" = "$today" ]; then
            serial_num=$(printf "%02d" $(( 10#$serial_num + 1 )))
        else
            serial_num="01"
        fi
        local new_serial="${today}${serial_num}"
        sed -i "s/${current_serial}\(\s*;\s*Serial\)/${new_serial}\1/" "$zone_file"
        info "Serial de la zona actualitzat: ${current_serial} -> ${new_serial}"
    fi

    # Afegir registres SPF, DKIM i DMARC per a professorat
    {
        echo ""
        echo "; --- Registres SPF, DKIM i DMARC per a ${domain} ---"
        echo "${domain}                       IN  TXT     \"v=spf1 ip4:10.26.50.0/24 mx ~all\""
        if [ -n "$dkim_record" ]; then
            echo "${dkim_record}"
        else
            warn "No s'ha pogut obtenir el registre DKIM de Stalwart"
        fi
        echo "_dmarc.${domain}                IN  TXT     \"v=DMARC1; p=none; rua=mailto:postmaster@${fqdn}\""
    } >> "$zone_file"

    ok "Registres DNS de ${domain} afegits a CoreDNS"

    # Esperar que CoreDNS recarregui
    local coredns_container="clab-${LAB_NAME}-coredns"
    if docker ps -q -f "name=${coredns_container}" | grep -q .; then
        info "CoreDNS recarregarà la zona automàticament en uns segons (reload plugin)..."
        sleep 6
        ok "Registres DNS de ${domain} actius a CoreDNS"
    fi
}

_setup_mailcow() {
    local alumni_container="clab-${LAB_NAME}-mail-alumni"
    local mailcow_dir="/opt/mailcow"
    local mailcow_api="http://localhost:8082/api/v1"
    local mailcow_api_key="mailcow-lab-api-key-2025"
    local domain="alumni.demoasixcloud2025.cat"
    local zone_file="${SCRIPT_DIR}/configs/coredns/zones/db.demoasixcloud2025.cat"

    info "Configurant Mailcow per a ${domain}..."

    # --- 1. Verificar que Mailcow està en marxa ---
    if ! docker compose -f "${mailcow_dir}/docker-compose.yml" --project-directory "${mailcow_dir}" ps --format json 2>/dev/null | grep -q postfix; then
        info "Iniciant Mailcow..."
        docker compose -f "${mailcow_dir}/docker-compose.yml" --project-directory "${mailcow_dir}" up -d
        info "Esperant que Mailcow estigui llest..."
        sleep 15
    fi
    ok "Mailcow en marxa"

    # --- 2. Generar DH params si no existeixen (2048 bits) ---
    if [ ! -f "${mailcow_dir}/data/assets/ssl/dhparams.pem" ]; then
        info "Generant paràmetres DH (2048 bits)..."
        openssl dhparam -out "${mailcow_dir}/data/assets/ssl/dhparams.pem" 2048
        # Reiniciar dovecot perquè carregui els DH params
        docker restart "$(docker compose -f "${mailcow_dir}/docker-compose.yml" --project-directory "${mailcow_dir}" ps -q dovecot-mailcow)"
        sleep 5
        ok "Paràmetres DH generats i dovecot reiniciat"
    fi

    # --- 3. Connectar mail-alumni al Docker network de Mailcow (veth pair) ---
    local alumni_pid
    alumni_pid=$(docker inspect "$alumni_container" --format '{{.State.Pid}}')
    local mailcow_bridge="br-mailcow"

    # Comprovar si ja està connectat (eth2 existent)
    if nsenter -t "$alumni_pid" -n ip addr show eth2 2>/dev/null | grep -q "172.22.1.30"; then
        info "mail-alumni ja connectat a la xarxa Mailcow (eth2)"
    else
        info "Connectant mail-alumni a la xarxa Mailcow..."
        # Crear veth pair
        ip link add mcow-alumni-h type veth peer name mcow-alumni-c 2>/dev/null || true
        ip link set mcow-alumni-h master "$mailcow_bridge"
        ip link set mcow-alumni-h up
        ip link set mcow-alumni-c netns "$alumni_pid"
        nsenter -t "$alumni_pid" -n ip link set mcow-alumni-c name eth2
        nsenter -t "$alumni_pid" -n ip addr add 172.22.1.30/24 dev eth2
        nsenter -t "$alumni_pid" -n ip link set eth2 up
        ok "mail-alumni connectat a la xarxa Mailcow (172.22.1.30)"
    fi

    # --- 4. Configurar iptables DNAT (forwarding de ports) ---
    # Postfix: 172.22.1.253, Dovecot: 172.22.1.250, Nginx: 172.22.1.11
    nsenter -t "$alumni_pid" -n sysctl -qw net.ipv4.ip_forward=1

    # Netejar regles anteriors si n'hi ha
    nsenter -t "$alumni_pid" -n iptables -t nat -F 2>/dev/null || true
    nsenter -t "$alumni_pid" -n iptables -F FORWARD 2>/dev/null || true

    # DNAT: eth1 (lab) -> mailcow containers (eth2)
    nsenter -t "$alumni_pid" -n iptables -t nat -A PREROUTING -i eth1 -p tcp --dport 25  -j DNAT --to-destination 172.22.1.253:25
    nsenter -t "$alumni_pid" -n iptables -t nat -A PREROUTING -i eth1 -p tcp --dport 587 -j DNAT --to-destination 172.22.1.253:587
    nsenter -t "$alumni_pid" -n iptables -t nat -A PREROUTING -i eth1 -p tcp --dport 143 -j DNAT --to-destination 172.22.1.250:143
    nsenter -t "$alumni_pid" -n iptables -t nat -A PREROUTING -i eth1 -p tcp --dport 993 -j DNAT --to-destination 172.22.1.250:993
    nsenter -t "$alumni_pid" -n iptables -t nat -A PREROUTING -i eth1 -p tcp --dport 8080 -j DNAT --to-destination 172.22.1.11:8080
    nsenter -t "$alumni_pid" -n iptables -t nat -A POSTROUTING -o eth2 -j MASQUERADE
    nsenter -t "$alumni_pid" -n iptables -A FORWARD -i eth1 -o eth2 -j ACCEPT
    nsenter -t "$alumni_pid" -n iptables -A FORWARD -i eth2 -o eth1 -m state --state RELATED,ESTABLISHED -j ACCEPT
    ok "Forwarding de ports configurat (SMTP/IMAP -> Mailcow)"

    # --- 5. Crear domini a Mailcow via API ---
    local api_response
    api_response=$(curl -s -X POST "${mailcow_api}/add/domain" \
        -H "X-API-Key: ${mailcow_api_key}" \
        -H "Content-Type: application/json" \
        -d "{\"domain\":\"${domain}\",\"description\":\"Domini alumni\",\"aliases\":400,\"mailboxes\":10,\"defquota\":1024,\"maxquota\":2048,\"restart_sogo\":1,\"active\":1}" 2>&1)
    if echo "$api_response" | grep -q "domain_added"; then
        ok "Domini ${domain} creat a Mailcow"
    elif echo "$api_response" | grep -q "is_now_active\|domain_exists"; then
        info "Domini ${domain} ja existeix a Mailcow"
    else
        warn "Resposta inesperada creant domini: ${api_response}"
    fi

    # --- 6. Crear bústia exalumne1 ---
    api_response=$(curl -s -X POST "${mailcow_api}/add/mailbox" \
        -H "X-API-Key: ${mailcow_api_key}" \
        -H "Content-Type: application/json" \
        -d "{\"local_part\":\"exalumne1\",\"domain\":\"${domain}\",\"name\":\"Ex-alumne 1\",\"password\":\"Exalumne1.2025\",\"password2\":\"Exalumne1.2025\",\"quota\":1024,\"active\":1}" 2>&1)
    if echo "$api_response" | grep -q "mailbox_added"; then
        ok "Bústia exalumne1@${domain} creada"
    elif echo "$api_response" | grep -q "object_exists"; then
        info "Bústia exalumne1@${domain} ja existeix"
    else
        warn "Resposta inesperada creant bústia: ${api_response}"
    fi

    # --- 7. Obtenir clau DKIM i afegir a CoreDNS ---
    local dkim_response
    dkim_response=$(curl -s "${mailcow_api}/get/dkim/${domain}" \
        -H "X-API-Key: ${mailcow_api_key}" 2>&1)
    local dkim_selector
    dkim_selector=$(echo "$dkim_response" | python3 -c "import sys,json; print(json.load(sys.stdin)['dkim_selector'])" 2>/dev/null || echo "")
    local dkim_txt
    dkim_txt=$(echo "$dkim_response" | python3 -c "import sys,json; print(json.load(sys.stdin)['dkim_txt'])" 2>/dev/null || echo "")

    if [ -z "$dkim_selector" ] || [ -z "$dkim_txt" ]; then
        warn "No s'ha pogut obtenir la clau DKIM de Mailcow. Caldrà afegir-la manualment."
        return 0
    fi

    info "DKIM selector: ${dkim_selector}, afegint registre DNS..."

    # Netejar registres anteriors d'alumni
    if grep -q "; --- Registres SPF, DKIM i DMARC per a alumni" "$zone_file" 2>/dev/null; then
        local tmp_file
        tmp_file=$(mktemp)
        awk '/^; --- Registres SPF, DKIM i DMARC per a alumni/{skip=1; next} /^$/{if(skip){skip=0; next}} !skip' "$zone_file" > "$tmp_file"
        sed -i -e :a -e '/^[[:space:]]*$/{ $d; N; ba' -e '}' "$tmp_file"
        cp "$tmp_file" "$zone_file"
        rm -f "$tmp_file"
    fi

    # Incrementar serial
    local current_serial
    current_serial=$(grep -oP '\d{10}(?=\s*;\s*Serial)' "$zone_file")
    if [ -n "$current_serial" ]; then
        local today
        today=$(date +%Y%m%d)
        local serial_date="${current_serial:0:8}"
        local serial_num="${current_serial:8:2}"
        if [ "$serial_date" = "$today" ]; then
            serial_num=$(printf "%02d" $(( 10#$serial_num + 1 )))
        else
            serial_num="01"
        fi
        local new_serial="${today}${serial_num}"
        sed -i "s/${current_serial}\(\s*;\s*Serial\)/${new_serial}\1/" "$zone_file"
        info "Serial de la zona actualitzat: ${current_serial} -> ${new_serial}"
    fi

    # Dividir DKIM TXT en trossos de 255 caràcters per a DNS
    local dkim_part1 dkim_part2
    if [ ${#dkim_txt} -gt 255 ]; then
        dkim_part1="${dkim_txt:0:255}"
        dkim_part2="${dkim_txt:255}"
        local dkim_dns_value="( \"${dkim_part1}\" \"${dkim_part2}\" )"
    else
        local dkim_dns_value="\"${dkim_txt}\""
    fi

    # Afegir registres SPF, DKIM i DMARC
    {
        echo ""
        echo "; --- Registres SPF, DKIM i DMARC per a alumni ---"
        echo "alumni                       IN  TXT     \"v=spf1 ip4:10.26.50.0/24 mx ~all\""
        echo "${dkim_selector}._domainkey.alumni  IN  TXT     ${dkim_dns_value}"
        echo "_dmarc.alumni                IN  TXT     \"v=DMARC1; p=none; rua=mailto:postmaster@${domain}\""
    } >> "$zone_file"

    ok "Registres DNS d'alumni (SPF + DKIM + DMARC) afegits a CoreDNS"

    # Esperar que CoreDNS recarregui
    local coredns_container="clab-${LAB_NAME}-coredns"
    if docker ps -q -f "name=${coredns_container}" | grep -q .; then
        info "CoreDNS recarregarà la zona automàticament en uns segons (reload plugin)..."
        sleep 6
        ok "Registres DNS d'alumni actius a CoreDNS"
    fi

    ok "Mailcow configurat correctament per a ${domain}"
}

# --- Comandes principals ---

cmd_build() {
    local target="${1:-all}"

    if [ "$target" = "all" ]; then
        info "Construint totes les imatges Docker personalitzades..."
        for img in mail-switch mail-client-swaks mail-acme; do
            _build_image "$img"
        done
    else
        _build_image "$target"
    fi
    ok "Construcció completada"
}

cmd_deploy() {
    local stage="${1:?Ús: ./lab.sh deploy <etapa>}"

    _check_prerequisites
    _load_env
    _ensure_images "$stage"

    local topo_file
    topo_file=$(_get_topology_file "$stage")

    info "Desplegant etapa ${stage} des de ${topo_file}..."

    # Crear directori de certificats si no existeix
    mkdir -p "${SCRIPT_DIR}/certs"

    sudo containerlab deploy \
        --topo "$topo_file" \
        --reconfigure

    # Configuració de xarxa post-desplegament
    _post_deploy_network "$stage"

    ok "Etapa ${stage} desplegada correctament"
    echo ""
    info "Pròxim pas: ./lab.sh setup ${stage}"
}

cmd_setup() {
    local stage="${1:?Ús: ./lab.sh setup <etapa>}"

    info "Executant setup post-desplegament per a l'etapa ${stage}..."

    case $stage in
        1)
            _setup_dms_accounts
            ok "Setup etapa 1 completat"
            ;;
        2)
            _setup_dms_accounts
            info "Generant certificats Let's Encrypt..."
            info "Executa: docker exec clab-${LAB_NAME}-acme bash /scripts/acme-certs.sh"
            ok "Setup etapa 2 completat"
            ;;
        3)
            _setup_dms_accounts
            ok "Setup etapa 3 completat"
            ;;
        4)
            _setup_dms_accounts
            _setup_dkim
            ok "Setup etapa 4 completat"
            info "Registres SPF, DKIM i DMARC afegits automàticament a CoreDNS"
            info "Recorda publicar també els registres a Cloudflare si cal resolució externa"
            ;;
        5)
            _setup_dms_accounts
            _setup_dkim
            # Setup Stalwart (s'executa des de client-swaks perquè el host no té ruta al lab)
            # Inclou creació de DKIM i registres DNS per a professorat
            _setup_stalwart
            ok "Setup etapa 5 completat"
            info "Registres SPF, DKIM i DMARC afegits per a alumnat i professorat"
            ;;
        6)
            _setup_dms_accounts
            _setup_dkim
            _setup_stalwart
            _setup_mailcow
            ok "Setup etapa 6 completat"
            info "Registres SPF, DKIM i DMARC afegits per a alumnat, professorat i alumni"
            ;;
        *)
            error "Etapa desconeguda: $stage"
            exit 1
            ;;
    esac
}

cmd_certs() {
    local domains="${1:-alumnat}"
    _load_env

    if [ -z "${CF_DNS_API_TOKEN:-}" ]; then
        error "CF_DNS_API_TOKEN no definit. Configura el fitxer .env"
        exit 1
    fi

    info "Generant certificats per a: ${domains}"

    local acme_container="clab-${LAB_NAME}-acme"
    if ! docker ps -q -f "name=${acme_container}" | grep -q .; then
        error "Contenidor ACME no trobat. Desplega primer una etapa >= 2"
        exit 1
    fi

    docker exec -e CF_DNS_API_TOKEN="${CF_DNS_API_TOKEN}" \
        -e DOMAINS="${domains}" \
        "$acme_container" bash /scripts/acme-certs.sh

    ok "Certificats generats per a: ${domains}"
}

cmd_destroy() {
    info "Destruint el laboratori..."

    # Trobar el fitxer de topologia actiu
    local topo_files
    topo_files=$(ls "${TOPOLOGIES_DIR}"/etapa*.yml 2>/dev/null)

    for topo_file in $topo_files; do
        local clab_dir="clab-${LAB_NAME}"
        if [ -d "${TOPOLOGIES_DIR}/${clab_dir}" ]; then
            sudo containerlab destroy --topo "$topo_file" --cleanup 2>/dev/null || true
            ok "Lab destruït: $topo_file"
            break
        fi
    done

    # Neteja alternativa
    sudo containerlab destroy --topo "${TOPOLOGIES_DIR}/etapa1.yml" --cleanup 2>/dev/null || true

    ok "Laboratori destruït"
}

cmd_status() {
    info "Estat del laboratori:"
    sudo containerlab inspect --all 2>/dev/null || warn "Cap lab actiu"
}

cmd_shell() {
    local node="${1:?Ús: ./lab.sh shell <node>}"
    local container="clab-${LAB_NAME}-${node}"

    if ! docker ps -q -f "name=${container}" | grep -q .; then
        error "Contenidor no trobat: ${container}"
        exit 1
    fi

    info "Obrint shell a ${container}..."
    docker exec -it "$container" bash 2>/dev/null || docker exec -it "$container" sh
}

cmd_logs() {
    local node="${1:?Ús: ./lab.sh logs <node>}"
    local container="clab-${LAB_NAME}-${node}"

    if ! docker ps -q -f "name=${container}" | grep -q .; then
        error "Contenidor no trobat: ${container}"
        exit 1
    fi

    docker logs -f "$container"
}

cmd_help() {
    echo "============================================"
    echo " Laboratori de Servidors de Correu"
    echo "============================================"
    echo ""
    echo "Ús: ./lab.sh <comanda> [arguments]"
    echo ""
    echo "Comandes:"
    echo "  build [target]    Construir imatges Docker (all, mail-switch, mail-client-swaks, mail-acme)"
    echo "  deploy <etapa>    Desplegar una etapa (1-6)"
    echo "  setup <etapa>     Executar configuració post-desplegament"
    echo "  certs [dominis]   Generar certificats Let's Encrypt"
    echo "  destroy           Destruir el laboratori"
    echo "  status            Mostrar estat del laboratori"
    echo "  shell <node>      Obrir shell a un node"
    echo "  logs <node>       Veure logs d'un node"
    echo "  help              Mostrar aquesta ajuda"
    echo ""
    echo "Etapes:"
    echo "  1  Correu bàsic amb DMS (sense TLS)"
    echo "  2  Certificats Let's Encrypt (TLS)"
    echo "  3  Enviament via terminal (swaks)"
    echo "  4  DKIM, DMARC, SPF"
    echo "  5  Stalwart + Roundcube"
    echo "  6  Mailcow"
    echo ""
    echo "Exemples:"
    echo "  ./lab.sh build                    # Construir totes les imatges"
    echo "  ./lab.sh deploy 1                 # Desplegar etapa 1"
    echo "  ./lab.sh setup 1                  # Configurar etapa 1"
    echo "  ./lab.sh shell mail-alumnat       # Shell al servidor de correu"
    echo "  ./lab.sh logs mail-alumnat        # Logs del servidor de correu"
    echo "  ./lab.sh certs alumnat            # Generar certificat per alumnat"
    echo "  ./lab.sh certs 'alumnat professorat'  # Generar certificats per 2 dominis"
    echo "  ./lab.sh destroy                  # Destruir tot"
}

# --- Main ---
COMMAND="${1:-help}"
shift || true

case $COMMAND in
    build)   cmd_build "$@" ;;
    deploy)  cmd_deploy "$@" ;;
    setup)   cmd_setup "$@" ;;
    certs)   cmd_certs "$@" ;;
    destroy) cmd_destroy "$@" ;;
    status)  cmd_status ;;
    shell)   cmd_shell "$@" ;;
    logs)    cmd_logs "$@" ;;
    help)    cmd_help ;;
    *)       error "Comanda desconeguda: $COMMAND"; cmd_help; exit 1 ;;
esac
