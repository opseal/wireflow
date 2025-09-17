# VPN Deployment Guide

This guide provides step-by-step instructions for deploying the secure VPN solution across different environments.

## Prerequisites

### System Requirements

**Minimum Requirements**:
- CPU: 2 cores
- RAM: 4GB
- Storage: 20GB SSD
- Network: 100 Mbps

**Recommended Requirements**:
- CPU: 4+ cores
- RAM: 8GB+
- Storage: 50GB+ SSD
- Network: 1 Gbps

### Software Dependencies

**Required**:
- Docker 20.10+
- Docker Compose 2.0+
- kubectl 1.24+
- terraform 1.0+

**Optional**:
- Git
- curl
- jq
- openssl

### Cloud Provider Setup

**AWS**:
- AWS CLI configured
- IAM user with appropriate permissions
- EKS cluster access

**GCP**:
- gcloud CLI configured
- Service account with required roles
- GKE cluster access

**Azure**:
- Azure CLI configured
- Service principal with required permissions
- AKS cluster access

## Quick Start (Local Development)

### 1. Clone Repository

```bash
git clone <repository-url>
cd VPN
```

### 2. Run Setup Script

```bash
chmod +x scripts/setup.sh
./scripts/setup.sh
```

### 3. Verify Installation

```bash
# Check services
docker-compose ps

# Test API
curl http://localhost:8080/health

# Test VPN (after adding a client)
docker exec vpn-wireguard wg show
```

## Production Deployment

### 1. Infrastructure Setup

#### Using Terraform

```bash
cd infrastructure

# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var="environment=prod" -var="region=us-west-2"

# Apply configuration
terraform apply
```

#### Manual Cloud Setup

**AWS EKS**:
```bash
# Create EKS cluster
eksctl create cluster --name vpn-cluster --region us-west-2 --nodes 3

# Configure kubectl
aws eks update-kubeconfig --region us-west-2 --name vpn-cluster
```

**GCP GKE**:
```bash
# Create GKE cluster
gcloud container clusters create vpn-cluster --zone us-west2-a --num-nodes 3

# Configure kubectl
gcloud container clusters get-credentials vpn-cluster --zone us-west2-a
```

### 2. Kubernetes Deployment

```bash
# Deploy to Kubernetes
chmod +x scripts/deploy-k8s.sh
./scripts/deploy-k8s.sh
```

### 3. Verify Deployment

```bash
# Check pods
kubectl get pods -n vpn-system

# Check services
kubectl get services -n vpn-system

# Check logs
kubectl logs -f deployment/vpn-wireguard -n vpn-system
```

## Configuration

### Environment Variables

Create a `.env` file with the following variables:

```bash
# VPN Configuration
WG_HOST=your-domain.com
WG_PORT=51820
WG_DEFAULT_ADDRESS=10.0.0.1
WG_DEFAULT_DNS=8.8.8.8

# API Configuration
JWT_SECRET=your-secret-key
DATABASE_URL=sqlite:///app/vpn.db
REDIS_URL=redis://redis:6379

# Monitoring
PROMETHEUS_RETENTION=200h
GRAFANA_ADMIN_PASSWORD=secure-password
```

### WireGuard Configuration

**Server Configuration** (`/etc/wireguard/wg0.conf`):
```ini
[Interface]
PrivateKey = SERVER_PRIVATE_KEY
Address = 10.0.0.1/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = CLIENT_PUBLIC_KEY
AllowedIPs = 10.0.0.2/32
```

**Client Configuration**:
```ini
[Interface]
PrivateKey = CLIENT_PRIVATE_KEY
Address = 10.0.0.2/24
DNS = 8.8.8.8

[Peer]
PublicKey = SERVER_PUBLIC_KEY
Endpoint = your-domain.com:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
```

## Client Management

### Adding a New Client

**Using Docker Compose**:
```bash
# Add client
docker exec vpn-wireguard /scripts/add-client.sh client1

# Get client config
docker exec vpn-wireguard cat /etc/wireguard/keys/client_client1.conf
```

**Using Kubernetes**:
```bash
# Add client via API
curl -X POST http://vpn-api-service:8080/api/clients \
  -H "Content-Type: application/json" \
  -d '{"name": "client1"}'

# Get client config
curl http://vpn-api-service:8080/api/clients/1/config
```

### Managing Clients

**List Clients**:
```bash
# Via API
curl http://localhost:8080/api/clients

# Via kubectl
kubectl exec -it deployment/vpn-wireguard -n vpn-system -- wg show
```

**Remove Client**:
```bash
# Via API
curl -X DELETE http://localhost:8080/api/clients/1

# Manual removal
docker exec vpn-wireguard wg set wg0 peer CLIENT_PUBLIC_KEY remove
```

## Monitoring and Logging

### Accessing Dashboards

**Grafana**:
- URL: http://localhost:3000
- Username: admin
- Password: admin123 (change in production)

**Prometheus**:
- URL: http://localhost:9090

**Kibana**:
- URL: http://localhost:5601

### Key Metrics

**VPN Metrics**:
- Active connections
- Traffic throughput
- Handshake frequency
- Error rates

**System Metrics**:
- CPU usage
- Memory usage
- Disk I/O
- Network I/O

### Log Analysis

**Application Logs**:
```bash
# Docker Compose
docker-compose logs -f vpn-api

# Kubernetes
kubectl logs -f deployment/vpn-api -n vpn-system
```

**System Logs**:
```bash
# WireGuard logs
journalctl -u wg-quick@wg0 -f

# Kernel logs
dmesg | grep wireguard
```

## Security Hardening

### 1. Network Security

**Firewall Rules**:
```bash
# Allow WireGuard traffic
ufw allow 51820/udp

# Allow SSH
ufw allow 22/tcp

# Allow API (if external access needed)
ufw allow 8080/tcp

# Enable firewall
ufw enable
```

**Network Policies (Kubernetes)**:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: vpn-network-policy
  namespace: vpn-system
spec:
  podSelector:
    matchLabels:
      app: vpn-wireguard
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: vpn-api
    ports:
    - protocol: UDP
      port: 51820
```

### 2. Application Security

**API Security**:
- Use strong JWT secrets
- Enable HTTPS/TLS
- Implement rate limiting
- Regular security updates

**Container Security**:
- Use non-root users
- Scan images for vulnerabilities
- Regular base image updates
- Minimal attack surface

### 3. Infrastructure Security

**Cloud Security**:
- Use VPC/private networks
- Implement security groups
- Enable encryption at rest
- Regular security audits

## Troubleshooting

### Common Issues

**1. VPN Connection Fails**
```bash
# Check WireGuard status
wg show

# Check firewall rules
iptables -L

# Check network connectivity
ping 8.8.8.8
```

**2. API Not Responding**
```bash
# Check API logs
docker-compose logs vpn-api

# Check API health
curl http://localhost:8080/health

# Check database
docker-compose exec vpn-api python -c "import sqlite3; print('DB OK')"
```

**3. Monitoring Not Working**
```bash
# Check Prometheus
curl http://localhost:9090/api/v1/targets

# Check Grafana
curl http://localhost:3000/api/health

# Check logs
docker-compose logs prometheus
```

### Performance Issues

**High CPU Usage**:
- Check for excessive connections
- Monitor system resources
- Optimize WireGuard configuration

**High Memory Usage**:
- Check for memory leaks
- Monitor application metrics
- Adjust resource limits

**Network Latency**:
- Check network configuration
- Monitor packet loss
- Optimize routing

## Backup and Recovery

### Backup Strategy

**Configuration Backup**:
```bash
# Backup WireGuard configs
tar -czf wireguard-backup.tar.gz data/wireguard/

# Backup database
docker-compose exec vpn-api python -c "import shutil; shutil.copy('/app/vpn.db', '/backup/vpn.db')"
```

**Infrastructure Backup**:
```bash
# Backup Terraform state
terraform state pull > terraform-state.json

# Backup Kubernetes configs
kubectl get all -n vpn-system -o yaml > k8s-backup.yaml
```

### Recovery Procedures

**1. Service Recovery**:
```bash
# Restart services
docker-compose restart

# Or in Kubernetes
kubectl rollout restart deployment/vpn-wireguard -n vpn-system
```

**2. Data Recovery**:
```bash
# Restore database
docker-compose exec vpn-api python -c "import shutil; shutil.copy('/backup/vpn.db', '/app/vpn.db')"

# Restore configurations
tar -xzf wireguard-backup.tar.gz
```

## Maintenance

### Regular Tasks

**Daily**:
- Check service health
- Monitor resource usage
- Review security logs

**Weekly**:
- Update dependencies
- Review performance metrics
- Backup configurations

**Monthly**:
- Security updates
- Performance optimization
- Disaster recovery testing

### Updates

**Application Updates**:
```bash
# Pull latest images
docker-compose pull

# Restart services
docker-compose up -d
```

**Infrastructure Updates**:
```bash
# Update Terraform
terraform plan
terraform apply

# Update Kubernetes
kubectl apply -f k8s/
```

## Support

### Getting Help

**Documentation**:
- Architecture documentation
- API documentation
- Troubleshooting guides

**Community**:
- GitHub issues
- Discussion forums
- Slack channels

**Professional Support**:
- Enterprise support
- Consulting services
- Training programs






