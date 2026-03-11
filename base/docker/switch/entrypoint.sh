#!/bin/bash
set -e

# --- Crear bridge intern ---
BRIDGE_NAME="br0"

ip link add name ${BRIDGE_NAME} type bridge
ip link set ${BRIDGE_NAME} up

# Afegir totes les interfícies eth al bridge (excepte eth0 que és management)
for iface in /sys/class/net/eth*; do
    iface_name=$(basename "$iface")
    if [ "$iface_name" != "eth0" ]; then
        ip link set "$iface_name" master ${BRIDGE_NAME}
        ip link set "$iface_name" up
    fi
done

echo "[switch] Bridge ${BRIDGE_NAME} creat amb interfícies: $(bridge link show | grep -oP 'eth\d+' | tr '\n' ' ')"

# Mantenir el contenidor viu
exec tail -f /dev/null
