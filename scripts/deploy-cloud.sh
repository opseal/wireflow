#!/bin/bash

# Multi-Cloud Deployment Script for VPN DevOps Project
# Supports AWS, GCP, Azure, and local clusters

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
CLOUD_PROVIDER=""
REGION="us-west-2"
CLUSTER_NAME="vpn-cluster"
NODE_COUNT=3
INSTANCE_TYPE="t3.medium"
ENVIRONMENT="prod"
ENABLE_MONITORING=true
ENABLE_BACKUP=true
DRY_RUN=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --cloud)
            CLOUD_PROVIDER="$2"
            shift 2
            ;;
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
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            echo "Usage: $0 --cloud PROVIDER [OPTIONS]"
            echo "Cloud Providers: aws, gcp, azure, local"
            echo "Options:"
            echo "  --cloud PROVIDER        Cloud provider (aws/gcp/azure/local)"
            echo "  --region REGION         Cloud region (default: us-west-2)"
            echo "  --cluster-name NAME     Cluster name (default: vpn-cluster)"
            echo "  --node-count COUNT      Number of worker nodes (default: 3)"
            echo "  --instance-type TYPE    Instance type (default: t3.medium)"
            echo "  --environment ENV       Environment (dev/staging/prod) (default: prod)"
            echo "  --no-monitoring         Disable monitoring stack"
            echo "  --no-backup             Disable backup configuration"
            echo "  --dry-run               Show what would be deployed without actually deploying"
            echo "  --help                  Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 --cloud aws --region us-west-2"
            echo "  $0 --cloud gcp --region us-central1"
            echo "  $0 --cloud azure --region eastus"
            echo "  $0 --cloud local --cluster-type minikube"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate cloud provider
if [ -z "$CLOUD_PROVIDER" ]; then
    print_error "Cloud provider is required. Use --cloud aws|gcp|azure|local"
    exit 1
fi

if [[ ! "$CLOUD_PROVIDER" =~ ^(aws|gcp|azure|local)$ ]]; then
    print_error "Unsupported cloud provider: $CLOUD_PROVIDER. Supported: aws, gcp, azure, local"
    exit 1
fi

print_header "Multi-Cloud VPN Deployment Script"
echo "========================================"
echo "Cloud Provider: $CLOUD_PROVIDER"
echo "Region: $REGION"
echo "Cluster Name: $CLUSTER_NAME"
echo "Node Count: $NODE_COUNT"
echo "Instance Type: $INSTANCE_TYPE"
echo "Environment: $ENVIRONMENT"
echo "Monitoring: $ENABLE_MONITORING"
echo "Backup: $ENABLE_BACKUP"
echo "Dry Run: $DRY_RUN"
echo "========================================"

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
    
    # Check cloud-specific tools
    case $CLOUD_PROVIDER in
        aws)
            if ! command -v aws &> /dev/null; then
                print_error "AWS CLI is not installed. Please install it first."
                exit 1
            fi
            if ! command -v eksctl &> /dev/null; then
                print_error "eksctl is not installed. Please install it first."
                exit 1
            fi
            if ! aws sts get-caller-identity &> /dev/null; then
                print_error "AWS credentials not configured. Please run 'aws configure' first."
                exit 1
            fi
            ;;
        gcp)
            if ! command -v gcloud &> /dev/null; then
                print_error "gcloud CLI is not installed. Please install it first."
                exit 1
            fi
            if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
                print_error "GCP authentication not configured. Please run 'gcloud auth login' first."
                exit 1
            fi
            ;;
        azure)
            if ! command -v az &> /dev/null; then
                print_error "Azure CLI is not installed. Please install it first."
                exit 1
            fi
            if ! az account show &> /dev/null; then
                print_error "Azure authentication not configured. Please run 'az login' first."
                exit 1
            fi
            ;;
        local)
            if ! command -v minikube &> /dev/null && ! command -v kind &> /dev/null && ! command -v k3s &> /dev/null && ! command -v microk8s &> /dev/null; then
                print_error "No local Kubernetes cluster tool found. Please install minikube, kind, k3s, or microk8s."
                exit 1
            fi
            ;;
    esac
    
    print_status "Prerequisites check completed."
}

# Deploy to AWS
deploy_aws() {
    print_status "Deploying to AWS..."
    
    if [ "$DRY_RUN" = true ]; then
        print_warning "Dry run mode - showing what would be deployed to AWS"
        echo "Would create EKS cluster: $CLUSTER_NAME in region: $REGION"
        echo "Would deploy VPN infrastructure with $NODE_COUNT nodes of type: $INSTANCE_TYPE"
        return 0
    fi
    
    # Create EKS cluster
    eksctl create cluster \
        --name $CLUSTER_NAME \
        --region $REGION \
        --nodes $NODE_COUNT \
        --node-type $INSTANCE_TYPE \
        --managed \
        --with-oidc \
        --ssh-access \
        --tags "Project=VPN-DevOps,Environment=$ENVIRONMENT" \
        --yes
    
    # Configure kubectl
    aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME
    
    # Deploy infrastructure
    cd infrastructure
    terraform init
    terraform workspace select $ENVIRONMENT || terraform workspace new $ENVIRONMENT
    terraform apply \
        -var="cloud_provider=aws" \
        -var="region=$REGION" \
        -var="cluster_name=$CLUSTER_NAME" \
        -var="node_count=$NODE_COUNT" \
        -var="instance_type=$INSTANCE_TYPE" \
        -var="environment=$ENVIRONMENT" \
        -auto-approve
    cd ..
    
    print_status "AWS deployment completed."
}

# Deploy to GCP
deploy_gcp() {
    print_status "Deploying to GCP..."
    
    if [ "$DRY_RUN" = true ]; then
        print_warning "Dry run mode - showing what would be deployed to GCP"
        echo "Would create GKE cluster: $CLUSTER_NAME in region: $REGION"
        echo "Would deploy VPN infrastructure with $NODE_COUNT nodes of type: $INSTANCE_TYPE"
        return 0
    fi
    
    # Set project
    PROJECT_ID=$(gcloud config get-value project)
    if [ -z "$PROJECT_ID" ]; then
        print_error "GCP project not set. Please run 'gcloud config set project PROJECT_ID' first."
        exit 1
    fi
    
    # Create GKE cluster
    gcloud container clusters create $CLUSTER_NAME \
        --region $REGION \
        --num-nodes $NODE_COUNT \
        --machine-type $INSTANCE_TYPE \
        --enable-autoscaling \
        --min-nodes 1 \
        --max-nodes 10 \
        --enable-autorepair \
        --enable-autoupgrade \
        --tags "vpn-devops,environment-$ENVIRONMENT"
    
    # Configure kubectl
    gcloud container clusters get-credentials $CLUSTER_NAME --region $REGION
    
    # Deploy infrastructure
    cd infrastructure
    terraform init
    terraform workspace select $ENVIRONMENT || terraform workspace new $ENVIRONMENT
    terraform apply \
        -var="cloud_provider=gcp" \
        -var="region=$REGION" \
        -var="cluster_name=$CLUSTER_NAME" \
        -var="node_count=$NODE_COUNT" \
        -var="instance_type=$INSTANCE_TYPE" \
        -var="environment=$ENVIRONMENT" \
        -var="gcp_project_id=$PROJECT_ID" \
        -auto-approve
    cd ..
    
    print_status "GCP deployment completed."
}

# Deploy to Azure
deploy_azure() {
    print_status "Deploying to Azure..."
    
    if [ "$DRY_RUN" = true ]; then
        print_warning "Dry run mode - showing what would be deployed to Azure"
        echo "Would create AKS cluster: $CLUSTER_NAME in region: $REGION"
        echo "Would deploy VPN infrastructure with $NODE_COUNT nodes of type: $INSTANCE_TYPE"
        return 0
    fi
    
    # Set subscription
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    if [ -z "$SUBSCRIPTION_ID" ]; then
        print_error "Azure subscription not set. Please run 'az login' first."
        exit 1
    fi
    
    # Create resource group
    RESOURCE_GROUP="${CLUSTER_NAME}-rg"
    az group create --name $RESOURCE_GROUP --location $REGION
    
    # Create AKS cluster
    az aks create \
        --resource-group $RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --location $REGION \
        --node-count $NODE_COUNT \
        --node-vm-size $INSTANCE_TYPE \
        --enable-addons monitoring \
        --enable-managed-identity \
        --generate-ssh-keys \
        --tags "Project=VPN-DevOps" "Environment=$ENVIRONMENT"
    
    # Configure kubectl
    az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME
    
    # Deploy infrastructure
    cd infrastructure
    terraform init
    terraform workspace select $ENVIRONMENT || terraform workspace new $ENVIRONMENT
    terraform apply \
        -var="cloud_provider=azurerm" \
        -var="region=$REGION" \
        -var="cluster_name=$CLUSTER_NAME" \
        -var="node_count=$NODE_COUNT" \
        -var="instance_type=$INSTANCE_TYPE" \
        -var="environment=$ENVIRONMENT" \
        -auto-approve
    cd ..
    
    print_status "Azure deployment completed."
}

# Deploy to local cluster
deploy_local() {
    print_status "Deploying to local cluster..."
    
    if [ "$DRY_RUN" = true ]; then
        print_warning "Dry run mode - showing what would be deployed locally"
        echo "Would create local Kubernetes cluster"
        echo "Would deploy VPN infrastructure with monitoring"
        return 0
    fi
    
    # Determine local cluster type
    LOCAL_CLUSTER_TYPE="minikube"
    if command -v kind &> /dev/null; then
        LOCAL_CLUSTER_TYPE="kind"
    elif command -v k3s &> /dev/null; then
        LOCAL_CLUSTER_TYPE="k3s"
    elif command -v microk8s &> /dev/null; then
        LOCAL_CLUSTER_TYPE="microk8s"
    fi
    
    # Deploy using local script
    ./scripts/deploy-local.sh --cluster-type $LOCAL_CLUSTER_TYPE --cluster-name $CLUSTER_NAME
    
    print_status "Local deployment completed."
}

# Install Helm charts
install_helm_charts() {
    print_status "Installing Helm charts..."
    
    if [ "$DRY_RUN" = true ]; then
        print_warning "Dry run mode - would install Helm charts"
        return 0
    fi
    
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
        --set ingress.hosts[0].host="vpn.$CLUSTER_NAME.$REGION.cloud.com" \
        --wait
    
    print_status "Helm charts installed successfully."
}

# Configure monitoring
configure_monitoring() {
    if [ "$ENABLE_MONITORING" = true ]; then
        print_status "Configuring monitoring stack..."
        
        if [ "$DRY_RUN" = true ]; then
            print_warning "Dry run mode - would configure monitoring"
            return 0
        fi
        
        # Install Prometheus
        helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
            --namespace monitoring \
            --create-namespace \
            --set grafana.adminPassword="admin123" \
            --set prometheus.prometheusSpec.retention="200h" \
            --wait
        
        print_status "Monitoring stack configured successfully."
    fi
}

# Verify deployment
verify_deployment() {
    print_status "Verifying deployment..."
    
    if [ "$DRY_RUN" = true ]; then
        print_warning "Dry run mode - would verify deployment"
        return 0
    fi
    
    # Check pods
    kubectl get pods -n vpn-system
    kubectl get pods -n monitoring 2>/dev/null || true
    
    # Check services
    kubectl get services -n vpn-system
    
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
    
    if [ "$DRY_RUN" = true ]; then
        print_warning "Dry run mode - no actual deployment performed"
        return 0
    fi
    
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
}

# Main execution
main() {
    check_prerequisites
    
    case $CLOUD_PROVIDER in
        aws)
            deploy_aws
            ;;
        gcp)
            deploy_gcp
            ;;
        azure)
            deploy_azure
            ;;
        local)
            deploy_local
            ;;
    esac
    
    install_helm_charts
    configure_monitoring
    verify_deployment
    show_access_info
}

# Run main function
main "$@"






