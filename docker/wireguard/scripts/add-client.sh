#!/bin/bash

set -e

# Configuration
WG_INTERFACE=${WG_INTERFACE:-wg0}
WG_DEFAULT_ADDRESS=${WG_DEFAULT_ADDRESS:-10.0.0.1}
WG_DEFAULT_DNS=${WG_DEFAULT_DNS:-8.8.8.8}

if [ $# -ne 1 ]; then
    echo "Usage: $0 <client_name>"
    exit 1
fi

CLIENT_NAME=$1
CLIENT_IP="10.0.0.$((2 + $(ls /etc/wireguard/keys/client_*_public 2>/dev/null | wc -l)))"

echo "Adding client: $CLIENT_NAME with IP: $CLIENT_IP"

# Generate client keys
wg genkey | tee /etc/wireguard/keys/client_${CLIENT_NAME}_private | wg pubkey > /etc/wireguard/keys/client_${CLIENT_NAME}_public
chmod 600 /etc/wireguard/keys/client_${CLIENT_NAME}_private
chmod 644 /etc/wireguard/keys/client_${CLIENT_NAME}_public

# Read keys
CLIENT_PRIVATE_KEY=$(cat /etc/wireguard/keys/client_${CLIENT_NAME}_private)
CLIENT_PUBLIC_KEY=$(cat /etc/wireguard/keys/client_${CLIENT_NAME}_public)
SERVER_PUBLIC_KEY=$(cat /etc/wireguard/keys/server_public)

# Add client to server config
cat >> /etc/wireguard/$WG_INTERFACE.conf << EOF

[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
AllowedIPs = $CLIENT_IP/32
EOF

# Reload WireGuard configuration
wg-quick down $WG_INTERFACE || true
wg-quick up $WG_INTERFACE

# Generate client configuration
cat > /etc/wireguard/keys/client_${CLIENT_NAME}.conf << EOF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_IP/24
DNS = $WG_DEFAULT_DNS

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $WG_HOST:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

echo "Client $CLIENT_NAME added successfully!"
echo "Client IP: $CLIENT_IP"
echo "Client config saved to: /etc/wireguard/keys/client_${CLIENT_NAME}.conf"
echo "Client Public Key: $CLIENT_PUBLIC_KEY"

