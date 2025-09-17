#!/bin/bash

# Kubernetes Deployment Script for VPN
# This script deploys the VPN infrastructure to Kubernetes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if cluster is accessible
check_cluster() {
    print_status "Checking Kubernetes cluster connectivity..."
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        print_error "Please ensure kubectl is configured correctly"
        exit 1
    fi
    
    print_status "Cluster connectivity confirmed"
}

# Create namespace
create_namespace() {
    print_status "Creating VPN namespace..."
    kubectl apply -f k8s/namespace.yaml
    print_status "Namespace created"
}

# Generate secrets
generate_secrets() {
    print_status "Generating Kubernetes secrets..."
    
    # Generate server private key if not exists
    if [ ! -f data/keys/server_private ]; then
        print_status "Generating WireGuard server keys..."
        mkdir -p data/keys
        wg genkey | tee data/keys/server_private | wg pubkey > data/keys/server_public
        chmod 600 data/keys/server_private
        chmod 644 data/keys/server_public
    fi
    
    # Read server private key
    SERVER_PRIVATE_KEY=$(cat data/keys/server_private | base64 -w 0)
    JWT_SECRET=$(openssl rand -base64 32 | base64 -w 0)
    DATABASE_URL=$(echo -n "sqlite:///app/vpn.db" | base64 -w 0)
    REDIS_URL=$(echo -n "redis://redis:6379" | base64 -w 0)
    
    # Create secrets
    cat > k8s/secrets-generated.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: vpn-secrets
  namespace: vpn-system
type: Opaque
data:
  server-private-key: $SERVER_PRIVATE_KEY
  jwt-secret: $JWT_SECRET
  database-url: $DATABASE_URL
  redis-url: $REDIS_URL
EOF
    
    kubectl apply -f k8s/secrets-generated.yaml
    print_status "Secrets generated and applied"
}

# Deploy ConfigMaps
deploy_configmaps() {
    print_status "Deploying ConfigMaps..."
    kubectl apply -f k8s/configmap.yaml
    print_status "ConfigMaps deployed"
}

# Deploy applications
deploy_applications() {
    print_status "Deploying VPN applications..."
    
    # Deploy WireGuard
    kubectl apply -f k8s/wireguard-deployment.yaml
    
    # Deploy API
    kubectl apply -f k8s/api-deployment.yaml
    
    # Deploy services
    kubectl apply -f k8s/services.yaml
    
    print_status "Applications deployed"
}

# Deploy monitoring
deploy_monitoring() {
    print_status "Deploying monitoring stack..."
    
    # Create monitoring namespace
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy Prometheus
    kubectl apply -f monitoring/prometheus/
    
    # Deploy Grafana
    kubectl apply -f monitoring/grafana/
    
    print_status "Monitoring stack deployed"
}

# Wait for deployments
wait_for_deployments() {
    print_status "Waiting for deployments to be ready..."
    
    # Wait for WireGuard deployment
    kubectl wait --for=condition=available --timeout=300s deployment/vpn-wireguard -n vpn-system
    
    # Wait for API deployment
    kubectl wait --for=condition=available --timeout=300s deployment/vpn-api -n vpn-system
    
    print_status "All deployments are ready"
}

# Display access information
show_access_info() {
    print_status "Kubernetes deployment complete!"
    echo ""
    echo "Access Information:"
    echo "=================="
    
    # Get service endpoints
    API_ENDPOINT=$(kubectl get service vpn-api-service -n vpn-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    VPN_ENDPOINT=$(kubectl get service vpn-wireguard-service -n vpn-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    if [ -n "$API_ENDPOINT" ]; then
        echo "VPN API: http://$API_ENDPOINT:8080"
    else
        echo "VPN API: Use 'kubectl port-forward service/vpn-api-service 8080:8080 -n vpn-system'"
    fi
    
    if [ -n "$VPN_ENDPOINT" ]; then
        echo "VPN Endpoint: $VPN_ENDPOINT:51820"
    else
        echo "VPN Endpoint: Use 'kubectl port-forward service/vpn-wireguard-service 51820:51820 -n vpn-system'"
    fi
    
    echo ""
    echo "To access services locally:"
    echo "  kubectl port-forward service/vpn-api-service 8080:8080 -n vpn-system"
    echo "  kubectl port-forward service/vpn-wireguard-service 51820:51820 -n vpn-system"
    echo ""
    echo "To view logs:"
    echo "  kubectl logs -f deployment/vpn-wireguard -n vpn-system"
    echo "  kubectl logs -f deployment/vpn-api -n vpn-system"
    echo ""
    echo "To scale deployments:"
    echo "  kubectl scale deployment vpn-wireguard --replicas=3 -n vpn-system"
    echo "  kubectl scale deployment vpn-api --replicas=3 -n vpn-system"
}

# Cleanup function
cleanup() {
    print_status "Cleaning up temporary files..."
    rm -f k8s/secrets-generated.yaml
}

# Main execution
main() {
    echo "Kubernetes VPN Deployment Script"
    echo "================================"
    echo ""
    
    # Set trap for cleanup
    trap cleanup EXIT
    
    check_cluster
    create_namespace
    generate_secrets
    deploy_configmaps
    deploy_applications
    deploy_monitoring
    wait_for_deployments
    show_access_info
}

# Run main function
main "$@"






