#!/bin/bash
set -e

# --- Inicialització del client swaks ---
SWAKS_IP="10.26.50.200"
GATEWAY="10.26.50.1"
DNS_SERVER="10.26.50.2"
LAN_IFACE="eth1"

echo "[client-swaks] Configurant xarxa..."
ip addr add ${SWAKS_IP}/24 dev ${LAN_IFACE} 2>/dev/null || true
ip link set ${LAN_IFACE} up
ip route add default via ${GATEWAY} 2>/dev/null || true

# Configurar DNS
echo "nameserver ${DNS_SERVER}" > /etc/resolv.conf
echo "search demoasixcloud2025.cat" >> /etc/resolv.conf

echo "[client-swaks] Client swaks inicialitzat: ${SWAKS_IP}/24"
