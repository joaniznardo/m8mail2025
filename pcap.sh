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
# ============================================================================

LAB_NAME="mailserver-lab"
NODE="${1:?Ús: ./pcap.sh <node> [interfície] [filtre]}"
IFACE="${2:-eth1}"
FILTER="${3:-}"

CONTAINER="clab-${LAB_NAME}-${NODE}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="${NODE}_${IFACE}_${TIMESTAMP}.pcapng"

# Verificar que el contenidor existeix
if ! docker ps -q -f "name=${CONTAINER}" | grep -q .; then
    echo "[ERROR] Contenidor no trobat: ${CONTAINER}"
    echo "Nodes disponibles:"
    docker ps --format '{{.Names}}' | grep "clab-${LAB_NAME}" | sed "s/clab-${LAB_NAME}-/  /"
    exit 1
fi

echo "============================================"
echo " Captura de paquets"
echo "============================================"
echo " Node:       ${NODE}"
echo " Contenidor: ${CONTAINER}"
echo " Interfície: ${IFACE}"
echo " Filtre:     ${FILTER:-cap (tot el tràfic)}"
echo " Sortida:    ${OUTPUT_FILE}"
echo "============================================"
echo ""
echo "Prem Ctrl+C per aturar la captura"
echo ""

# Capturar paquets
if [ -n "$FILTER" ]; then
    docker exec -it "${CONTAINER}" tcpdump -i "${IFACE}" -w "/tmp/${OUTPUT_FILE}" ${FILTER}
else
    docker exec -it "${CONTAINER}" tcpdump -i "${IFACE}" -w "/tmp/${OUTPUT_FILE}"
fi

# Copiar el fitxer de captura al host
docker cp "${CONTAINER}:/tmp/${OUTPUT_FILE}" "./${OUTPUT_FILE}"
echo ""
echo "[OK] Captura desada a: ./${OUTPUT_FILE}"
echo "     Obre amb: wireshark ./${OUTPUT_FILE}"
