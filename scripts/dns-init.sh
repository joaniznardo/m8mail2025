#!/bin/bash
set -e

# --- Inicialització del DNS CoreDNS ---
DNS_IP="10.26.50.2"
GATEWAY="10.26.50.1"
LAN_IFACE="eth1"

echo "[dns] Configurant xarxa..."
ip addr add ${DNS_IP}/24 dev ${LAN_IFACE} 2>/dev/null || true
ip link set ${LAN_IFACE} up
ip route add default via ${GATEWAY} 2>/dev/null || true

echo "[dns] CoreDNS inicialitzat: ${DNS_IP}/24"
