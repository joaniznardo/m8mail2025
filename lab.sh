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
    info "Generant claus DKIM per a alumnat.demoasixcloud2025.cat..."

    docker exec "$container" setup config dkim keysize 2048 domain alumnat.demoasixcloud2025.cat 2>/dev/null || true
    ok "DKIM configurat. Publica el registre DNS des de:"
    ok "docker exec ${container} cat /tmp/docker-mailserver/opendkim/keys/alumnat.demoasixcloud2025.cat/mail.txt"
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
            info "Recorda publicar els registres SPF, DKIM i DMARC a Cloudflare"
            ;;
        5)
            _setup_dms_accounts
            _setup_dkim
            # Setup Stalwart (s'executa des de client-swaks perquè el host no té ruta al lab)
            _setup_stalwart
            ok "Setup etapa 5 completat"
            ;;
        6)
            _setup_dms_accounts
            _setup_dkim
            _setup_stalwart
            info "Mailcow requereix configuració manual addicional."
            info "Consulta les instruccions de l'etapa 6."
            ok "Setup etapa 6 completat"
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
