#!/bin/bash
set -e

# --- Script de generació de certificats Let's Encrypt ---
# Utilitza acme.sh amb validació DNS via Cloudflare

ACME_IP="10.26.50.250"
GATEWAY="10.26.50.1"
DNS_SERVER="10.26.50.2"
LAN_IFACE="eth1"
CERT_DIR="/certs"

# --- Configurar xarxa ---
echo "[acme] Configurant xarxa..."
ip addr add ${ACME_IP}/24 dev ${LAN_IFACE} 2>/dev/null || true
ip link set ${LAN_IFACE} up
ip route add default via ${GATEWAY} 2>/dev/null || true
echo "nameserver ${DNS_SERVER}" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

# --- Verificar variables d'entorn ---
if [ -z "${CF_DNS_API_TOKEN}" ]; then
    echo "[acme] ERROR: CF_DNS_API_TOKEN no està definit"
    echo "[acme] Configura el fitxer .env amb el token d'API de Cloudflare"
    exit 1
fi

export CF_Token="${CF_DNS_API_TOKEN}"

# --- Funció per generar certificats per un domini ---
generate_cert() {
    local DOMAIN=$1
    local CERT_NAME=$2

    echo "[acme] Generant certificat per a ${DOMAIN}..."

    /root/.acme.sh/acme.sh --issue \
        --dns dns_cf \
        -d "${DOMAIN}" \
        -d "mail.${DOMAIN}" \
        -d "autoconfig.${DOMAIN}" \
        -d "autodiscover.${DOMAIN}" \
        --server letsencrypt \
        --keylength 4096 \
        --force

    # Instal·lar certificats al directori compartit
    mkdir -p "${CERT_DIR}/${CERT_NAME}"
    /root/.acme.sh/acme.sh --install-cert -d "${DOMAIN}" \
        --cert-file "${CERT_DIR}/${CERT_NAME}/cert.pem" \
        --key-file "${CERT_DIR}/${CERT_NAME}/key.pem" \
        --fullchain-file "${CERT_DIR}/${CERT_NAME}/fullchain.pem" \
        --ca-file "${CERT_DIR}/${CERT_NAME}/ca.pem"

    echo "[acme] Certificat per a ${DOMAIN} instal·lat a ${CERT_DIR}/${CERT_NAME}/"
}

# --- Generar certificats segons els dominis sol·licitats ---
DOMAINS="${DOMAINS:-alumnat}"

for domain_label in ${DOMAINS}; do
    case ${domain_label} in
        alumnat)
            generate_cert "alumnat.demoasixcloud2025.cat" "alumnat"
            ;;
        professorat)
            generate_cert "professorat.demoasixcloud2025.cat" "professorat"
            ;;
        alumni)
            generate_cert "alumni.demoasixcloud2025.cat" "alumni"
            ;;
        *)
            echo "[acme] Domini desconegut: ${domain_label}"
            ;;
    esac
done

echo "[acme] Tots els certificats generats correctament"
ls -la ${CERT_DIR}/*/
