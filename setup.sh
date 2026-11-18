#!/bin/sh
# ==============================================================================
# JioFiber Asterisk Global PBX - Automated Setup Wizard (Idempotent)
# Author: Mus'ab (@musabtvt)
# https://github.com/musabtvt/jiofiber-asterisk-global-pbx
# ==============================================================================

set -e

echo "=========================================================="
echo "🌍 JioFiber Asterisk Global PBX Setup Wizard"
echo "   Developed by Mus'ab (@musabtvt)"
echo "=========================================================="

# Check for Docker and Docker Compose
if ! command -v docker >/dev/null 2>&1; then
    echo "[-] Error: Docker is not installed. Please install Docker first:"
    echo "    curl -fsSL https://get.docker.com | sh"
    exit 1
fi

echo ""
echo "Please enter your configuration details:"
printf "Enter your Jio Fixed Line Number (e.g. +912212345678): "
read -r USER_JIO_NUM

printf "Enter password for Softphone 1001 (Your Mobile): "
read -r USER_PASS_1001

printf "Enter password for Softphone 1002 (Your Laptop): "
read -r USER_PASS_1002

# Get Public IP
DETECTED_IP=$(curl -s https://api.ipify.org 2>/dev/null || curl -s https://icanhazip.com 2>/dev/null || echo "127.0.0.1")
printf "Enter your VPS Public IP [%s]: " "$DETECTED_IP"
read -r USER_VPS_IP
if [ -z "$USER_VPS_IP" ]; then
    USER_VPS_IP="$DETECTED_IP"
fi

# Write .env file
cat <<EOF > .env
JIO_LANDLINE_NUMBER=${USER_JIO_NUM}
EXT_1001_PASSWORD=${USER_PASS_1001}
EXT_1002_PASSWORD=${USER_PASS_1002}
VPS_PUBLIC_IP=${USER_VPS_IP}
EOF

# Auto-generate self-signed TLS certificates for PJSIP TLS transport if missing
mkdir -p asterisk/keys
if [ ! -f asterisk/keys/asterisk.crt ] || [ ! -f asterisk/keys/asterisk.key ]; then
    echo "[*] Generating self-signed TLS certificates for SIP TLS encryption..."
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
        -keyout asterisk/keys/asterisk.key -out asterisk/keys/asterisk.crt \
        -subj "/C=IN/ST=India/L=JioPBX/O=SelfHosted/CN=${USER_VPS_IP}" >/dev/null 2>&1 || true
    echo "[+] TLS certificates created in asterisk/keys/"
fi

# Idempotently generate pjsip.conf from template
if [ -f asterisk/pjsip.conf.template ]; then
    sed -e "s/{{EXT_1001_PASSWORD}}/${USER_PASS_1001}/g" \
        -e "s/{{EXT_1002_PASSWORD}}/${USER_PASS_1002}/g" \
        asterisk/pjsip.conf.template > asterisk/pjsip.conf
fi

# Idempotently generate extensions.conf from template
if [ -f asterisk/extensions.conf.template ]; then
    sed -e "s/{{JIO_LANDLINE_NUMBER}}/${USER_JIO_NUM}/g" \
        asterisk/extensions.conf.template > asterisk/extensions.conf
fi

echo "[+] Configurations successfully generated from templates."

echo "[*] Launching Asterisk PBX container via Docker Compose..."
docker compose up -d

echo ""
echo "=========================================================="
echo "🎉 SUCCESS: Your JioFiber Global PBX is now running!"
echo "=========================================================="
echo "• PBX Host (UDP):         ${USER_VPS_IP}:5060"
echo "• PBX Host (TLS):         ${USER_VPS_IP}:5061"
echo "• Mobile Extension:       1001 (Password: ${USER_PASS_1001})"
echo "• Laptop Extension:       1002 (Password: ${USER_PASS_1002})"
echo "• TLS Cert Directory:     ./asterisk/keys/"
echo "• Reverse Tunnel Script:  ./router-agent/setup_router_tunnel.sh"
echo "=========================================================="
