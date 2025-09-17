FROM alpine:3.18

# Install WireGuard and other dependencies
RUN apk add --no-cache \
    wireguard-tools \
    iptables \
    ip6tables \
    bash \
    curl \
    jq \
    && rm -rf /var/cache/apk/*

# Create directories
RUN mkdir -p /etc/wireguard/keys

# Copy configuration scripts
COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh

# Create wireguard config directory
RUN mkdir -p /etc/wireguard

# Expose WireGuard port
EXPOSE 51820/udp

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wg show || exit 1

# Start WireGuard
CMD ["/scripts/start.sh"]

