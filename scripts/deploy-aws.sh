#!/bin/bash

# AWS Deployment Script for VPN DevOps Project
# This script deploys the VPN infrastructure to AWS using Terraform and Helm

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
REGION="us-west-2"
CLUSTER_NAME="vpn-cluster"
NODE_COUNT=3
INSTANCE_TYPE="t3.medium"
ENVIRONMENT="prod"
ENABLE_MONITORING=true
ENABLE_BACKUP=true

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --region)
            REGION="$2"
            shift 2
            ;;
        --cluster-name)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --node-count)
            NODE_COUNT="$2"
            shift 2
            ;;
        --instance-type)
            INSTANCE_TYPE="$2"
            shift 2
            ;;
        --environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --no-monitoring)
            ENABLE_MONITORING=false
            shift
            ;;
        --no-backup)
            ENABLE_BACKUP=false
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --region REGION           AWS region (default: us-west-2)"
            echo "  --cluster-name NAME       EKS cluster name (default: vpn-cluster)"
            echo "  --node-count COUNT        Number of worker nodes (default: 3)"
            echo "  --instance-type TYPE      EC2 instance type (default: t3.medium)"
            echo "  --environment ENV         Environment (dev/staging/prod) (default: prod)"
            echo "  --no-monitoring           Disable monitoring stack"
            echo "  --no-backup               Disable backup configuration"
            echo "  --help                    Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

print_header "AWS VPN Deployment Script"
echo "=================================="
echo "Region: $REGION"
echo "Cluster Name: $CLUSTER_NAME"
echo "Node Count: $NODE_COUNT"
echo "Instance Type: $INSTANCE_TYPE"
echo "Environment: $ENVIRONMENT"
echo "Monitoring: $ENABLE_MONITORING"
echo "Backup: $ENABLE_BACKUP"
echo "=================================="

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install it first."
        exit 1
    fi
    
    # Check terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    # Check helm
    if ! command -v helm &> /dev/null; then
        print_error "Helm is not installed. Please install it first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_status "Prerequisites check completed."
}

# Create EKS cluster
create_eks_cluster() {
    print_status "Creating EKS cluster..."
    
    # Create cluster using eksctl
    eksctl create cluster \
        --name $CLUSTER_NAME \
        --region $REGION \
        --nodes $NODE_COUNT \
        --node-type $INSTANCE_TYPE \
        --managed \
        --with-oidc \
        --ssh-access \
        --ssh-public-key $(aws ec2 describe-key-pairs --query 'KeyPairs[0].KeyName' --output text) \
        --nodegroup-name workers \
        --node-labels "node-type=workers" \
        --tags "Project=VPN-DevOps,Environment=$ENVIRONMENT" \
        --yes
    
    # Configure kubectl
    aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME
    
    print_status "EKS cluster created successfully."
}

# Deploy infrastructure
deploy_infrastructure() {
    print_status "Deploying infrastructure with Terraform..."
    
    cd infrastructure
    
    # Initialize Terraform
    terraform init
    
    # Create workspace
    terraform workspace select $ENVIRONMENT || terraform workspace new $ENVIRONMENT
    
    # Plan deployment
    terraform plan \
        -var="cloud_provider=aws" \
        -var="region=$REGION" \
        -var="cluster_name=$CLUSTER_NAME" \
        -var="node_count=$NODE_COUNT" \
        -var="instance_type=$INSTANCE_TYPE" \
        -var="environment=$ENVIRONMENT" \
        -out=tfplan
    
    # Apply configuration
    terraform apply tfplan
    
    cd ..
    
    print_status "Infrastructure deployed successfully."
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
    kubectl create namespace vpn-system --dry-run=client -o yaml | kubectl apply -f -
    
    # Install VPN Helm chart
    helm upgrade --install vpn ./helm/vpn \
        --namespace vpn-system \
        --set global.imageRegistry="" \
        --set wireguard.replicaCount=2 \
        --set api.replicaCount=3 \
        --set monitoring.enabled=$ENABLE_MONITORING \
        --set backup.enabled=$ENABLE_BACKUP \
        --set ingress.enabled=true \
        --set ingress.hosts[0].host="vpn.$CLUSTER_NAME.$REGION.aws.com" \
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
            --set prometheus.prometheusSpec.retention="200h" \
            --wait
        
        # Install ELK stack
        helm upgrade --install elasticsearch elastic/elasticsearch \
            --namespace logging \
            --create-namespace \
            --set replicas=1 \
            --set "esJavaOpts=-Xms512m -Xmx512m" \
            --wait
        
        helm upgrade --install kibana elastic/kibana \
            --namespace logging \
            --set elasticsearchHosts="http://elasticsearch-master:9200" \
            --wait
        
        print_status "Monitoring stack configured successfully."
    fi
}

# Configure backup
configure_backup() {
    if [ "$ENABLE_BACKUP" = true ]; then
        print_status "Configuring backup..."
        
        # Install Velero for backup
        helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
        helm repo update
        
        # Create S3 bucket for backups
        BUCKET_NAME="vpn-backups-$CLUSTER_NAME-$(date +%s)"
        aws s3 mb s3://$BUCKET_NAME --region $REGION
        
        # Install Velero
        helm upgrade --install velero vmware-tanzu/velero \
            --namespace velero \
            --create-namespace \
            --set credentials.useSecret=false \
            --set configuration.provider=aws \
            --set configuration.backupStorageLocation.bucket=$BUCKET_NAME \
            --set configuration.backupStorageLocation.config.region=$REGION \
            --set configuration.volumeSnapshotLocation.config.region=$REGION \
            --wait
        
        print_status "Backup configured successfully."
    fi
}

# Verify deployment
verify_deployment() {
    print_status "Verifying deployment..."
    
    # Check pods
    kubectl get pods -n vpn-system
    kubectl get pods -n monitoring 2>/dev/null || true
    kubectl get pods -n logging 2>/dev/null || true
    
    # Check services
    kubectl get services -n vpn-system
    
    # Check ingress
    kubectl get ingress -n vpn-system
    
    # Wait for services to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/vpn-api -n vpn-system
    kubectl wait --for=condition=available --timeout=300s deployment/vpn-wireguard -n vpn-system
    
    print_status "Deployment verification completed."
}

# Display access information
show_access_info() {
    print_header "Deployment Complete!"
    echo ""
    echo "Access Information:"
    echo "=================="
    
    # Get service endpoints
    API_ENDPOINT=$(kubectl get service vpn-api -n vpn-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "Not available")
    VPN_ENDPOINT=$(kubectl get service vpn-wireguard -n vpn-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "Not available")
    GRAFANA_ENDPOINT=$(kubectl get service prometheus-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "Not available")
    
    echo "VPN API: http://$API_ENDPOINT:8080"
    echo "VPN Endpoint: $VPN_ENDPOINT:51820"
    echo "Grafana Dashboard: http://$GRAFANA_ENDPOINT:3000 (admin/admin123)"
    echo ""
    echo "To access services locally:"
    echo "  kubectl port-forward service/vpn-api 8080:8080 -n vpn-system"
    echo "  kubectl port-forward service/vpn-wireguard 51820:51820 -n vpn-system"
    echo "  kubectl port-forward service/prometheus-grafana 3000:80 -n monitoring"
    echo ""
    echo "To add a VPN client:"
    echo "  kubectl exec -it deployment/vpn-api -n vpn-system -- python -c \"from app import create_client; create_client('client1')\""
    echo ""
    echo "To view logs:"
    echo "  kubectl logs -f deployment/vpn-api -n vpn-system"
    echo "  kubectl logs -f deployment/vpn-wireguard -n vpn-system"
    echo ""
    echo "To scale deployments:"
    echo "  kubectl scale deployment vpn-wireguard --replicas=5 -n vpn-system"
    echo "  kubectl scale deployment vpn-api --replicas=5 -n vpn-system"
}

# Cleanup function
cleanup() {
    print_warning "Cleaning up temporary files..."
    rm -f infrastructure/tfplan
}

# Main execution
main() {
    # Set trap for cleanup
    trap cleanup EXIT
    
    check_prerequisites
    create_eks_cluster
    deploy_infrastructure
    install_helm_charts
    configure_monitoring
    configure_backup
    verify_deployment
    show_access_info
}

# Run main function
main "$@"






