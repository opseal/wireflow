#!/bin/bash

# Local Kubernetes Deployment Script for WireFlow VPN
# Supports minikube, kind, k3s, and microk8s

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_header() {
    echo -e "${BLUE}[HEADER]${NC} $1"
}

# Default values
CLUSTER_TYPE="minikube"
CLUSTER_NAME="vpn-cluster"
ENABLE_MONITORING=true
ENABLE_INGRESS=true
MEMORY="4g"
CPUS=2

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --cluster-type)
            CLUSTER_TYPE="$2"
            shift 2
            ;;
        --cluster-name)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --no-monitoring)
            ENABLE_MONITORING=false
            shift
            ;;
        --no-ingress)
            ENABLE_INGRESS=false
            shift
            ;;
        --memory)
            MEMORY="$2"
            shift 2
            ;;
        --cpus)
            CPUS="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --cluster-type TYPE     Local cluster type (minikube/kind/k3s/microk8s) (default: minikube)"
            echo "  --cluster-name NAME     Cluster name (default: vpn-cluster)"
            echo "  --no-monitoring         Disable monitoring stack"
            echo "  --no-ingress            Disable ingress controller"
            echo "  --memory MEMORY         Memory allocation (default: 4g)"
            echo "  --cpus CPUS             CPU allocation (default: 2)"
            echo "  --help                  Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

print_header "Local WireFlow VPN Deployment Script"
echo "=================================="
echo "Cluster Type: $CLUSTER_TYPE"
echo "Cluster Name: $CLUSTER_NAME"
echo "Monitoring: $ENABLE_MONITORING"
echo "Ingress: $ENABLE_INGRESS"
echo "Memory: $MEMORY"
echo "CPUs: $CPUS"
echo "=================================="

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install it first."
        exit 1
    fi
    
    # Check helm
    if ! command -v helm &> /dev/null; then
        print_error "Helm is not installed. Please install it first."
        exit 1
    fi
    
    # Check cluster-specific tools
    case $CLUSTER_TYPE in
        minikube)
            if ! command -v minikube &> /dev/null; then
                print_error "minikube is not installed. Please install it first."
                exit 1
            fi
            ;;
        kind)
            if ! command -v kind &> /dev/null; then
                print_error "kind is not installed. Please install it first."
                exit 1
            fi
            ;;
        k3s)
            if ! command -v k3s &> /dev/null; then
                print_error "k3s is not installed. Please install it first."
                exit 1
            fi
            ;;
        microk8s)
            if ! command -v microk8s &> /dev/null; then
                print_error "microk8s is not installed. Please install it first."
                exit 1
            fi
            ;;
        *)
            print_error "Unsupported cluster type: $CLUSTER_TYPE"
            exit 1
            ;;
    esac
    
    print_status "Prerequisites check completed."
}

# Create local cluster
create_local_cluster() {
    print_status "Creating local $CLUSTER_TYPE cluster..."
    
    case $CLUSTER_TYPE in
        minikube)
            # Start minikube
            minikube start \
                --memory=$MEMORY \
                --cpus=$CPUS \
                --driver=docker \
                --kubernetes-version=v1.28.0
            
            # Enable addons
            minikube addons enable ingress
            minikube addons enable metrics-server
            minikube addons enable dashboard
            ;;
        kind)
            # Create kind cluster
            cat <<EOF | kind create cluster --name $CLUSTER_NAME --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
  - containerPort: 51820
    hostPort: 51820
    protocol: UDP
EOF
            ;;
        k3s)
            # Start k3s
            curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
            export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
            ;;
        microk8s)
            # Start microk8s
            microk8s start
            microk8s enable ingress
            microk8s enable metrics-server
            microk8s enable dashboard
            ;;
    esac
    
    print_status "Local cluster created successfully."
}

# Install ingress controller
install_ingress() {
    if [ "$ENABLE_INGRESS" = true ]; then
        print_status "Installing ingress controller..."
        
        case $CLUSTER_TYPE in
            minikube)
                # Ingress is already enabled via addon
                print_status "Ingress controller already enabled in minikube."
                ;;
            kind)
                # Install NGINX ingress
                kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
                kubectl wait --namespace ingress-nginx \
                    --for=condition=ready pod \
                    --selector=app.kubernetes.io/component=controller \
                    --timeout=90s
                ;;
            k3s)
                # K3s comes with Traefik ingress by default
                print_status "Traefik ingress controller is enabled by default in k3s."
                ;;
            microk8s)
                # Ingress is already enabled via addon
                print_status "Ingress controller already enabled in microk8s."
                ;;
        esac
        
        print_status "Ingress controller installed successfully."
    fi
}

# Install Helm charts
install_helm_charts() {
    print_status "Installing Helm charts..."
    
    # Add required Helm repositories
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo add elastic https://helm.elastic.co
    helm repo update
    
    # Create namespace
    kubectl create namespace wireflow-system --dry-run=client -o yaml | kubectl apply -f -
    
    # Install WireFlow VPN Helm chart
    helm upgrade --install wireflow ./helm/vpn \
        --namespace wireflow-system \
        --set global.imageRegistry="" \
        --set wireguard.replicaCount=1 \
        --set api.replicaCount=1 \
        --set monitoring.enabled=$ENABLE_MONITORING \
        --set ingress.enabled=$ENABLE_INGRESS \
        --set ingress.hosts[0].host="wireflow.local" \
        --wait
    
    print_status "Helm charts installed successfully."
}

# Configure monitoring
configure_monitoring() {
    if [ "$ENABLE_MONITORING" = true ]; then
        print_status "Configuring monitoring stack..."
        
        # Install Prometheus
        helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
            --namespace monitoring \
            --create-namespace \
            --set grafana.adminPassword="admin123" \
            --set prometheus.prometheusSpec.retention="24h" \
            --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage="5Gi" \
            --wait
        
        print_status "Monitoring stack configured successfully."
    fi
}

# Configure port forwarding
configure_port_forwarding() {
    print_status "Configuring port forwarding..."
    
    # Start port forwarding in background
    kubectl port-forward service/wireflow-api 8080:8080 -n wireflow-system &
    kubectl port-forward service/wireflow-wireguard 51820:51820 -n wireflow-system &
    
    if [ "$ENABLE_MONITORING" = true ]; then
        kubectl port-forward service/prometheus-grafana 3000:80 -n monitoring &
    fi
    
    print_status "Port forwarding configured successfully."
}

# Verify deployment
verify_deployment() {
    print_status "Verifying deployment..."
    
    # Check pods
    kubectl get pods -n wireflow-system
    kubectl get pods -n monitoring 2>/dev/null || true
    
    # Check services
    kubectl get services -n wireflow-system
    
    # Check ingress
    kubectl get ingress -n wireflow-system 2>/dev/null || true
    
    # Wait for services to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/wireflow-api -n wireflow-system
    kubectl wait --for=condition=available --timeout=300s deployment/wireflow-wireguard -n wireflow-system
    
    print_status "Deployment verification completed."
}

# Display access information
show_access_info() {
    print_header "Deployment Complete!"
    echo ""
    echo "Access Information:"
    echo "=================="
    
    case $CLUSTER_TYPE in
        minikube)
            MINIKUBE_IP=$(minikube ip)
            echo "WireFlow VPN API: http://$MINIKUBE_IP:8080"
            echo "WireFlow VPN Endpoint: $MINIKUBE_IP:51820"
            echo "Grafana Dashboard: http://$MINIKUBE_IP:3000 (admin/admin123)"
            echo "Kubernetes Dashboard: minikube dashboard"
            ;;
        kind)
            echo "WireFlow VPN API: http://localhost:8080"
            echo "WireFlow VPN Endpoint: localhost:51820"
            echo "Grafana Dashboard: http://localhost:3000 (admin/admin123)"
            ;;
        k3s)
            echo "WireFlow VPN API: http://localhost:8080"
            echo "WireFlow VPN Endpoint: localhost:51820"
            echo "Grafana Dashboard: http://localhost:3000 (admin/admin123)"
            ;;
        microk8s)
            echo "WireFlow VPN API: http://localhost:8080"
            echo "WireFlow VPN Endpoint: localhost:51820"
            echo "Grafana Dashboard: http://localhost:3000 (admin/admin123)"
            echo "Kubernetes Dashboard: microk8s dashboard-proxy"
            ;;
    esac
    
    echo ""
    echo "To add a WireFlow VPN client:"
    echo "  kubectl exec -it deployment/wireflow-api -n wireflow-system -- python -c \"from app import create_client; create_client('client1')\""
    echo ""
    echo "To view logs:"
    echo "  kubectl logs -f deployment/wireflow-api -n wireflow-system"
    echo "  kubectl logs -f deployment/wireflow-wireguard -n wireflow-system"
    echo ""
    echo "To scale deployments:"
    echo "  kubectl scale deployment wireflow-wireguard --replicas=2 -n wireflow-system"
    echo "  kubectl scale deployment wireflow-api --replicas=2 -n wireflow-system"
    echo ""
    echo "To stop the cluster:"
    case $CLUSTER_TYPE in
        minikube)
            echo "  minikube stop"
            ;;
        kind)
            echo "  kind delete cluster --name $CLUSTER_NAME"
            ;;
        k3s)
            echo "  sudo k3s-uninstall.sh"
            ;;
        microk8s)
            echo "  microk8s stop"
            ;;
    esac
}

# Cleanup function
cleanup() {
    print_warning "Cleaning up port forwarding processes..."
    pkill -f "kubectl port-forward" || true
}

# Main execution
main() {
    # Set trap for cleanup
    trap cleanup EXIT
    
    check_prerequisites
    create_local_cluster
    install_ingress
    install_helm_charts
    configure_monitoring
    configure_port_forwarding
    verify_deployment
    show_access_info
}

# Run main function
main "$@"






