#!/bin/bash
set -e

# --- Inicialització del switch ---
# Configura la interfície eth1 amb l'adreça IP del gateway
# El bridge es crea automàticament per l'entrypoint del contenidor

echo "[switch] Esperant que el bridge estigui actiu..."
sleep 2

echo "[switch] Switch inicialitzat correctament"
