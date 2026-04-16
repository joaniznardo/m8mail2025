#!/bin/bash
set -e

# --- Setup de Stalwart: crear domini, comptes d'usuari i DKIM ---
# S'executa després del desplegament amb: ./lab.sh setup 5
# Requereix accés a la xarxa del lab (s'executa des de client-swaks o des del host amb ruta)
# Escriu els registres DNS a /tmp/stalwart-dns-records.json per a que lab.sh els afegeixi a CoreDNS

STALWART_HOST="10.26.50.20"
STALWART_ADMIN="admin"
STALWART_PASS="Admin.2025"
API_URL="http://${STALWART_HOST}:8080/api"
DOMAIN="professorat.demoasixcloud2025.cat"

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
echo "[setup-stalwart] Creant domini ${DOMAIN}..."
curl -sf -X POST "${API_URL}/principal" \
    -H "Authorization: Basic ${AUTH}" \
    -H "Content-Type: application/json" \
    -d "{
        \"type\": \"domain\",
        \"name\": \"${DOMAIN}\"
    }" || true

# Crear signatura DKIM (RSA-SHA256, 2048 bits)
echo "[setup-stalwart] Creant signatura DKIM per a ${DOMAIN}..."
curl -sf -X POST "${API_URL}/dkim" \
    -H "Authorization: Basic ${AUTH}" \
    -H "Content-Type: application/json" \
    -d "{
        \"id\": null,
        \"algorithm\": \"Rsa\",
        \"domain\": \"${DOMAIN}\",
        \"selector\": null
    }" || true

# Configurar TLS sortint per acceptar certificats no vàlids (entorn de laboratori)
echo "[setup-stalwart] Configurant TLS sortint per acceptar certificats del lab..."
curl -sf -X POST "${API_URL}/settings" \
    -H "Authorization: Basic ${AUTH}" \
    -H "Content-Type: application/json" \
    -d '[
        {"type":"clear","prefix":"queue.tls.default."},
        {"type":"set","key":"queue.tls.default.allow-invalid-certs","value":"true"},
        {"type":"set","key":"queue.tls.default.starttls","value":"optional"},
        {"type":"set","key":"queue.tls.default.dane","value":"disable"},
        {"type":"set","key":"queue.tls.default.mta-sts","value":"disable"},
        {"type":"set","key":"queue.tls.default.description","value":"TLS lab (certificats no verificats)"}
    ]' || true

# Crear comptes d'usuari
echo "[setup-stalwart] Creant compte profe1..."
curl -sf -X POST "${API_URL}/principal" \
    -H "Authorization: Basic ${AUTH}" \
    -H "Content-Type: application/json" \
    -d '{
        "type": "individual",
        "name": "profe1",
        "secrets": ["{PLAIN}Profe1.2025"],
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
        "secrets": ["{PLAIN}Profe2.2025"],
        "emails": ["profe2@professorat.demoasixcloud2025.cat"],
        "description": "Professor 2",
        "roles": ["user"],
        "enabledPermissions": ["authenticate", "email-send", "email-receive", "jmap-email-get"]
    }' || true

echo ""
echo "[setup-stalwart] Verificant comptes creats..."
curl -sf -H "Authorization: Basic ${AUTH}" "${API_URL}/principal" 2>&1
echo ""

# Obtenir registres DNS per al domini (inclou DKIM, SPF, MX, etc.)
echo "[setup-stalwart] Obtenint registres DNS de Stalwart per a ${DOMAIN}..."
DNS_RECORDS=$(curl -sf -H "Authorization: Basic ${AUTH}" "${API_URL}/dns/records/${DOMAIN}" 2>/dev/null)
if [ -n "$DNS_RECORDS" ]; then
    echo "$DNS_RECORDS" > /tmp/stalwart-dns-records.json
    echo "[setup-stalwart] Registres DNS guardats a /tmp/stalwart-dns-records.json"
    echo "$DNS_RECORDS"
else
    echo "[setup-stalwart] AVÍS: No s'han pogut obtenir els registres DNS"
fi

echo ""
echo "[setup-stalwart] Setup completat"
