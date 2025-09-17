#!/bin/bash

# WireFlow VPN Setup Script
# This script sets up the complete WireFlow VPN infrastructure

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

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root"
   exit 1
fi

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_warning "kubectl is not installed. Kubernetes deployment will not be available."
    fi
    
    # Check terraform
    if ! command -v terraform &> /dev/null; then
        print_warning "Terraform is not installed. Infrastructure deployment will not be available."
    fi
    
    print_status "Prerequisites check completed."
}

# Create necessary directories
create_directories() {
    print_status "Creating necessary directories..."
    
    mkdir -p data/wireguard
    mkdir -p data/keys
    mkdir -p logs
    mkdir -p backups
    
    print_status "Directories created."
}

# Generate initial configuration
generate_config() {
    print_status "Generating initial configuration..."
    
    # Generate WireGuard server keys
    if [ ! -f data/keys/server_private ]; then
        print_status "Generating WireGuard server keys..."
        wg genkey | tee data/keys/server_private | wg pubkey > data/keys/server_public
        chmod 600 data/keys/server_private
        chmod 644 data/keys/server_public
    fi
    
    # Generate JWT secret
    if [ ! -f .env ]; then
        print_status "Creating environment file..."
        cat > .env << EOF
# VPN Configuration
WG_HOST=localhost
WG_PORT=51820
WG_DEFAULT_ADDRESS=10.0.0.1
WG_DEFAULT_DNS=8.8.8.8

# API Configuration
JWT_SECRET=$(openssl rand -base64 32)
DATABASE_URL=sqlite:///app/vpn.db
REDIS_URL=redis://redis:6379

# Monitoring
PROMETHEUS_RETENTION=200h
GRAFANA_ADMIN_PASSWORD=admin123
EOF
    fi
    
    print_status "Configuration generated."
}

# Build Docker images
build_images() {
    print_status "Building Docker images..."
    
    # Build WireGuard image
    docker build -t vpn-wireguard:latest ./docker/wireguard/
    
    # Build API image
    docker build -t vpn-api:latest ./src/api/
    
    print_status "Docker images built successfully."
}

# Start services
start_services() {
    print_status "Starting WireFlow VPN services..."
    
    # Start with Docker Compose
    docker-compose up -d
    
    # Wait for services to be ready
    print_status "Waiting for services to start..."
    sleep 30
    
    # Check service health
    if curl -f http://localhost:8080/health > /dev/null 2>&1; then
        print_status "WireFlow VPN API is healthy"
    else
        print_warning "WireFlow VPN API health check failed"
    fi
    
    if curl -f http://localhost:3000 > /dev/null 2>&1; then
        print_status "Grafana is accessible"
    else
        print_warning "Grafana is not accessible"
    fi
    
    print_status "Services started successfully."
}

# Display access information
show_access_info() {
    print_status "WireFlow VPN Setup Complete!"
    echo ""
    echo "Access Information:"
    echo "=================="
    echo "WireFlow VPN API: http://localhost:8080"
    echo "Grafana Dashboard: http://localhost:3000 (admin/admin123)"
    echo "Prometheus: http://localhost:9090"
    echo "Kibana: http://localhost:5601"
    echo "HAProxy Stats: http://localhost:8404/stats"
    echo ""
    echo "WireGuard Server Public Key:"
    if [ -f data/keys/server_public ]; then
        cat data/keys/server_public
    fi
    echo ""
    echo "To add a WireFlow VPN client:"
    echo "  docker exec wireflow-wireguard /scripts/add-client.sh <client_name>"
    echo ""
    echo "To view logs:"
    echo "  docker-compose logs -f"
    echo ""
    echo "To stop services:"
    echo "  docker-compose down"
}

# Main execution
main() {
    echo "WireFlow VPN Setup Script"
    echo "=========================="
    echo ""
    
    check_prerequisites
    create_directories
    generate_config
    build_images
    start_services
    show_access_info
}

# Run main function
main "$@"






