#!/bin/bash
set -e

# --- Inicialització del router FRR ---
# La configuració de xarxa es fa via exec al containerlab
# FRR arranca automàticament amb la configuració muntada

ROUTER_IP="10.26.50.1"
LAN_IFACE="eth1"

echo "[router] Configurant interfície LAN..."
ip addr add ${ROUTER_IP}/24 dev ${LAN_IFACE} 2>/dev/null || true
ip link set ${LAN_IFACE} up

# Activar forwarding
sysctl -w net.ipv4.ip_forward=1 > /dev/null

echo "[router] Router inicialitzat: ${ROUTER_IP}/24 a ${LAN_IFACE}"
