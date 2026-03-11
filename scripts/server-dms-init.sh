#!/bin/bash
set -e

# --- Inicialització de docker-mailserver ---
DMS_IP="10.26.50.10"
GATEWAY="10.26.50.1"
DNS_SERVER="10.26.50.2"
LAN_IFACE="eth1"

echo "[mail-alumnat] Configurant xarxa..."
ip addr add ${DMS_IP}/24 dev ${LAN_IFACE} 2>/dev/null || true
ip link set ${LAN_IFACE} up
ip route add default via ${GATEWAY} 2>/dev/null || true

# Configurar DNS
echo "nameserver ${DNS_SERVER}" > /etc/resolv.conf
echo "search alumnat.demoasixcloud2025.cat demoasixcloud2025.cat" >> /etc/resolv.conf

echo "[mail-alumnat] docker-mailserver inicialitzat: ${DMS_IP}/24"
