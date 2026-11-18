#!/bin/sh
# ==============================================================================
# OpenWrt Router Agent - WireGuard Tunnel to Asterisk VPS PBX
# Bridges VPS Asterisk server to Jio Voice VLAN 406 securely
# ==============================================================================

set -e

VPS_HOST=""
VPS_WG_PORT="51820"
ROUTER_WG_IP="10.10.10.2/24"
VPS_WG_IP="10.10.10.1"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --server) VPS_HOST="$2"; shift 2;;
        --port) VPS_WG_PORT="$2"; shift 2;;
        *) echo "Unknown parameter: $1"; exit 1;;
    esac
done

if [ -z "$VPS_HOST" ]; then
    echo "Usage: $0 --server <VPS_PUBLIC_IP> [--port 51820]"
    exit 1
fi

echo "[*] Setting up WireGuard tunnel to Asterisk PBX at $VPS_HOST..."

# Install WireGuard packages if missing (Supports OpenWrt 25.x apk and 23.05/24.10 opkg)
if command -v apk >/dev/null 2>&1; then
    apk update >/dev/null 2>&1 || true
    apk add wireguard-tools kmod-wireguard luci-proto-wireguard >/dev/null 2>&1 || true
elif command -v opkg >/dev/null 2>&1; then
    opkg update >/dev/null 2>&1 || true
    opkg install wireguard-tools kmod-wireguard luci-proto-wireguard >/dev/null 2>&1 || true
fi

# Generate router WireGuard keys if not present
mkdir -p /etc/wireguard
if [ ! -f /etc/wireguard/router_private.key ]; then
    wg genkey | tee /etc/wireguard/router_private.key | wg pubkey > /etc/wireguard/router_public.key
fi

ROUTER_PUBKEY=$(cat /etc/wireguard/router_public.key)
ROUTER_PRIVKEY=$(cat /etc/wireguard/router_private.key)

echo "[+] Router WireGuard Public Key: $ROUTER_PUBKEY"

# Configure UCI network for wg0
uci set network.wg_vps=interface
uci set network.wg_vps.proto='wireguard'
uci set network.wg_vps.private_key="$ROUTER_PRIVKEY"
uci set network.wg_vps.addresses="$ROUTER_WG_IP"

# Configure peer (VPS)
uci delete network.wg_peer 2>/dev/null || true
uci set network.wg_peer=wireguard_wg_vps
uci set network.wg_peer.endpoint_host="$VPS_HOST"
uci set network.wg_peer.endpoint_port="$VPS_WG_PORT"
uci set network.wg_peer.allowed_ips="10.10.10.0/24"
uci set network.wg_peer.persistent_keepalive='25'

# Firewall zone for WireGuard tunnel
uci set firewall.wg_zone=zone
uci set firewall.wg_zone.name='wg_vps'
uci set firewall.wg_zone.network='wg_vps'
uci set firewall.wg_zone.input='ACCEPT'
uci set firewall.wg_zone.output='ACCEPT'
uci set firewall.wg_zone.forward='ACCEPT'
uci set firewall.wg_zone.masq='1'

# Allow forwarding between WireGuard and Voice VLAN
uci set firewall.wg_to_voice=forwarding
uci set firewall.wg_to_voice.src='wg_vps'
uci set firewall.wg_to_voice.dest='voice'

uci set firewall.voice_to_wg=forwarding
uci set firewall.voice_to_wg.src='voice'
uci set firewall.voice_to_wg.dest='wg_vps'

# Enforce masquerade on voice zone so VPS packets exit with router's voice IP
uci set firewall.voice_zone.masq='1'
uci set firewall.voice_zone.masq6='1'

uci commit network
uci commit firewall
/etc/init.d/network reload
/etc/init.d/firewall reload

echo "[SUCCESS] WireGuard reverse tunnel configured. Add $ROUTER_PUBKEY to your VPS peer list!"
