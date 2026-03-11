#!/bin/bash
set -e

echo "[client-swaks] Contenidor inicialitzat"
echo "[client-swaks] Eines disponibles: swaks, dig, tcpdump, openssl, ncat"

# Mantenir el contenidor viu
exec tail -f /dev/null
