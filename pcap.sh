#!/bin/bash
set -euo pipefail

# ============================================================================
# pcap.sh — Script per capturar paquets de xarxa d'un node del laboratori
# ============================================================================
# Ús: ./pcap.sh <node> [interfície] [filtre]
# Exemples:
#   ./pcap.sh mail-alumnat                       # Capturar tot a eth1
#   ./pcap.sh mail-alumnat eth1                  # Capturar a eth1
#   ./pcap.sh mail-alumnat eth1 "port 25"        # Capturar només SMTP
#   ./pcap.sh mail-alumnat eth1 "port 143"       # Capturar només IMAP
#   ./pcap.sh mail-alumnat eth1 "port 993"       # Capturar només IMAPS
#   ./pcap.sh mail-alumnat eth1 "port 25 or port 587 or port 465"  # Tot SMTP
#
# Nota: Utilitza nsenter per executar tcpdump del host dins el namespace de
#       xarxa del contenidor, ja que la majoria d'imatges no tenen tcpdump.
# ============================================================================

LAB_NAME="mailserver-lab"
NODE="${1:?Ús: ./pcap.sh <node> [interfície] [filtre]}"
IFACE="${2:-eth1}"
FILTER="${3:-}"

CONTAINER="clab-${LAB_NAME}-${NODE}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CAPTURES_DIR="captures"
OUTPUT_FILE="${CAPTURES_DIR}/${NODE}_${IFACE}_${TIMESTAMP}.pcapng"

# --- Verificar que tcpdump està instal·lat al host ---
if ! command -v tcpdump &>/dev/null; then
    echo "[ERROR] tcpdump no trobat al host. Instal·la'l amb:"
    echo "        sudo apt install tcpdump"
    exit 1
fi

# --- Verificar que el contenidor existeix ---
if ! docker ps -q -f "name=^${CONTAINER}$" | grep -q .; then
    echo "[ERROR] Contenidor no trobat: ${CONTAINER}"
    echo "Nodes disponibles:"
    docker ps --format '{{.Names}}' | grep "clab-${LAB_NAME}" | sed "s/clab-${LAB_NAME}-/  /"
    exit 1
fi

# --- Obtenir el PID del contenidor ---
PID=$(docker inspect -f '{{.State.Pid}}' "${CONTAINER}")
if [ -z "$PID" ] || [ "$PID" = "0" ]; then
    echo "[ERROR] No s'ha pogut obtenir el PID del contenidor ${CONTAINER}"
    exit 1
fi

# --- Crear directori de captures ---
mkdir -p "${CAPTURES_DIR}"

echo "============================================"
echo " Captura de paquets"
echo "============================================"
echo " Node:       ${NODE}"
echo " Contenidor: ${CONTAINER} (PID: ${PID})"
echo " Interfície: ${IFACE}"
echo " Filtre:     ${FILTER:-cap (tot el tràfic)}"
echo " Sortida:    ${OUTPUT_FILE}"
echo "============================================"
echo ""
echo "Prem Ctrl+C per aturar la captura"
echo ""

# --- Capturar paquets via nsenter al namespace de xarxa del contenidor ---
# shellcheck disable=SC2086
sudo nsenter -t "${PID}" -n tcpdump -i "${IFACE}" -w "${OUTPUT_FILE}" ${FILTER} || true

echo ""
if [ -f "${OUTPUT_FILE}" ]; then
    SIZE=$(du -h "${OUTPUT_FILE}" | cut -f1)
    echo "[OK] Captura desada a: ${OUTPUT_FILE} (${SIZE})"
    echo "     Obre amb: wireshark ${OUTPUT_FILE}"
else
    echo "[WARN] No s'ha generat cap fitxer de captura."
fi
