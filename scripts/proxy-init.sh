#!/bin/bash
set -e

# --- Inicialització del proxy Nginx ---
PROXY_IP="10.26.50.3"
GATEWAY="10.26.50.1"
DNS_SERVER="10.26.50.2"
LAN_IFACE="eth1"

echo "[proxy] Configurant xarxa..."
ip addr add ${PROXY_IP}/24 dev ${LAN_IFACE} 2>/dev/null || true
ip link set ${LAN_IFACE} up
ip route add default via ${GATEWAY} 2>/dev/null || true

# Configurar DNS
echo "nameserver ${DNS_SERVER}" > /etc/resolv.conf
echo "search demoasixcloud2025.cat" >> /etc/resolv.conf

echo "[proxy] Proxy Nginx inicialitzat: ${PROXY_IP}/24"
