#!/bin/bash
set -e

# --- Inicialització del client Thunderbird ---
# Les variables d'entorn TB_IP, TB_GATEWAY, TB_DNS es passen via containerlab
TB_IP="${TB_IP:-10.26.50.100}"
TB_GATEWAY="${TB_GATEWAY:-10.26.50.1}"
TB_DNS="${TB_DNS:-10.26.50.2}"
LAN_IFACE="eth1"

echo "[thunderbird] Configurant xarxa..."
ip addr add ${TB_IP}/24 dev ${LAN_IFACE} 2>/dev/null || true
ip link set ${LAN_IFACE} up
ip route add default via ${TB_GATEWAY} 2>/dev/null || true

# Configurar DNS
echo "nameserver ${TB_DNS}" > /etc/resolv.conf
echo "search demoasixcloud2025.cat" >> /etc/resolv.conf

echo "[thunderbird] Thunderbird inicialitzat: ${TB_IP}/24"
