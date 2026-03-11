#!/bin/bash
set -e

echo "[acme] Contenidor ACME inicialitzat"
echo "[acme] acme.sh disponible per generar certificats Let's Encrypt"

# Mantenir el contenidor viu
exec tail -f /dev/null
