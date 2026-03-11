#!/bin/bash
set -e

# --- Setup de Stalwart: crear domini i comptes d'usuari ---
# S'executa després del desplegament amb: ./lab.sh setup 5
# Requereix accés a la xarxa del lab (s'executa des de client-swaks o des del host amb ruta)

STALWART_HOST="10.26.50.20"
STALWART_ADMIN="admin"
STALWART_PASS="Admin.2025"
API_URL="http://${STALWART_HOST}:8080/api"

echo "[setup-stalwart] Esperant que Stalwart estigui disponible..."
for i in $(seq 1 30); do
    if curl -sf "${API_URL}/principal" -H "Authorization: Basic $(echo -n "${STALWART_ADMIN}:${STALWART_PASS}" | base64)" > /dev/null 2>&1; then
        echo "[setup-stalwart] Stalwart disponible"
        break
    fi
    echo "[setup-stalwart] Esperant... (${i}/30)"
    sleep 5
done

# Autenticació
AUTH=$(echo -n "${STALWART_ADMIN}:${STALWART_PASS}" | base64)

# Crear domini (com a principal de tipus "domain")
echo "[setup-stalwart] Creant domini professorat.demoasixcloud2025.cat..."
curl -sf -X POST "${API_URL}/principal" \
    -H "Authorization: Basic ${AUTH}" \
    -H "Content-Type: application/json" \
    -d '{
        "type": "domain",
        "name": "professorat.demoasixcloud2025.cat"
    }' || true

# Crear comptes d'usuari
echo "[setup-stalwart] Creant compte profe1..."
curl -sf -X POST "${API_URL}/principal" \
    -H "Authorization: Basic ${AUTH}" \
    -H "Content-Type: application/json" \
    -d '{
        "type": "individual",
        "name": "profe1",
        "secrets": ["Profe1.2025"],
        "emails": ["profe1@professorat.demoasixcloud2025.cat"],
        "description": "Professor 1",
        "roles": ["user"],
        "enabledPermissions": ["authenticate", "email-send", "email-receive", "jmap-email-get"]
    }' || true

echo "[setup-stalwart] Creant compte profe2..."
curl -sf -X POST "${API_URL}/principal" \
    -H "Authorization: Basic ${AUTH}" \
    -H "Content-Type: application/json" \
    -d '{
        "type": "individual",
        "name": "profe2",
        "secrets": ["Profe2.2025"],
        "emails": ["profe2@professorat.demoasixcloud2025.cat"],
        "description": "Professor 2",
        "roles": ["user"],
        "enabledPermissions": ["authenticate", "email-send", "email-receive", "jmap-email-get"]
    }' || true

echo ""
echo "[setup-stalwart] Verificant comptes creats..."
curl -sf -H "Authorization: Basic ${AUTH}" "${API_URL}/principal" 2>&1
echo ""
echo "[setup-stalwart] Setup completat"
