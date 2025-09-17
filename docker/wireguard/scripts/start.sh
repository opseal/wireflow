#!/bin/bash

set -e

# Configuration
WG_INTERFACE=${WG_INTERFACE:-wg0}
WG_HOST=${WG_HOST:-$(curl -s ifconfig.me)}
WG_PORT=${WG_PORT:-51820}
WG_DEFAULT_ADDRESS=${WG_DEFAULT_ADDRESS:-10.0.0.1}
WG_DEFAULT_DNS=${WG_DEFAULT_DNS:-8.8.8.8}

echo "Starting WireGuard VPN Server..."
echo "Host: $WG_HOST"
echo "Port: $WG_PORT"
echo "Interface: $WG_INTERFACE"

# Generate server keys if they don't exist
if [ ! -f /etc/wireguard/keys/server_private ]; then
    echo "Generating server keys..."
    wg genkey | tee /etc/wireguard/keys/server_private | wg pubkey > /etc/wireguard/keys/server_public
    chmod 600 /etc/wireguard/keys/server_private
    chmod 644 /etc/wireguard/keys/server_public
fi

# Read server keys
SERVER_PRIVATE_KEY=$(cat /etc/wireguard/keys/server_private)
SERVER_PUBLIC_KEY=$(cat /etc/wireguard/keys/server_public)

echo "Server Public Key: $SERVER_PUBLIC_KEY"

# Create WireGuard configuration
cat > /etc/wireguard/$WG_INTERFACE.conf << EOF
[Interface]
PrivateKey = $SERVER_PRIVATE_KEY
Address = $WG_DEFAULT_ADDRESS/24
ListenPort = $WG_PORT
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

# Client configurations will be added here dynamically
EOF

# Set up IP forwarding
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
sysctl -p

# Start WireGuard
echo "Starting WireGuard interface..."
wg-quick up $WG_INTERFACE

# Keep the container running and show status
echo "WireGuard is running!"
echo "Interface status:"
wg show

# Monitor WireGuard status
while true; do
    sleep 30
    if ! wg show $WG_INTERFACE > /dev/null 2>&1; then
        echo "WireGuard interface is down, restarting..."
        wg-quick down $WG_INTERFACE || true
        wg-quick up $WG_INTERFACE
    fi
done

