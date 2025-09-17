# VPN Infrastructure with Terraform
# Supports AWS, GCP, and Azure

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

# Variables
variable "cloud_provider" {
  description = "Cloud provider (aws, gcp, azure)"
  type        = string
  default     = "aws"
  validation {
    condition     = contains(["aws", "gcp", "azurerm"], var.cloud_provider)
    error_message = "Cloud provider must be aws, gcp, or azurerm."
  }
}

variable "region" {
  description = "Cloud region"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
  default     = "vpn-cluster"
}

variable "node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 3
}

variable "instance_type" {
  description = "Instance type for worker nodes"
  type        = string
  default     = "t3.medium"
}

# Local values
locals {
  common_tags = {
    Project     = "VPN-DevOps"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Configure providers based on cloud provider
provider "aws" {
  region = var.region
  default_tags {
    tags = local.common_tags
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.region
}

provider "azurerm" {
  features {}
}

# Data sources
data "aws_availability_zones" "available" {
  count = var.cloud_provider == "aws" ? 1 : 0
  state = "available"
}

data "google_client_config" "default" {
  count = var.cloud_provider == "gcp" ? 1 : 0
}

# VPC/Network Configuration
module "vpc" {
  source = "./modules/vpc"
  
  cloud_provider = var.cloud_provider
  region         = var.region
  environment    = var.environment
  cluster_name   = var.cluster_name
  
  # AWS specific
  availability_zones = var.cloud_provider == "aws" ? data.aws_availability_zones.available[0].names : []
  
  # GCP specific
  gcp_project_id = var.cloud_provider == "gcp" ? var.gcp_project_id : null
  
  tags = local.common_tags
}

# Kubernetes Cluster
module "kubernetes" {
  source = "./modules/kubernetes"
  
  cloud_provider = var.cloud_provider
  region         = var.region
  environment    = var.environment
  cluster_name   = var.cluster_name
  node_count     = var.node_count
  instance_type  = var.instance_type
  
  # Network configuration
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  # GCP specific
  gcp_project_id = var.cloud_provider == "gcp" ? var.gcp_project_id : null
  
  tags = local.common_tags
}

# Security Groups/Network Security
module "security" {
  source = "./modules/security"
  
  cloud_provider = var.cloud_provider
  vpc_id         = module.vpc.vpc_id
  cluster_id     = module.kubernetes.cluster_id
  
  tags = local.common_tags
}

# Monitoring and Logging
module "monitoring" {
  source = "./modules/monitoring"
  
  cloud_provider = var.cloud_provider
  cluster_id     = module.kubernetes.cluster_id
  region         = var.region
  
  tags = local.common_tags
}

# Outputs
output "cluster_endpoint" {
  description = "Kubernetes cluster endpoint"
  value       = module.kubernetes.cluster_endpoint
}

output "cluster_ca_certificate" {
  description = "Kubernetes cluster CA certificate"
  value       = module.kubernetes.cluster_ca_certificate
  sensitive   = true
}

output "vpn_endpoint" {
  description = "VPN server endpoint"
  value       = module.kubernetes.vpn_endpoint
}

output "monitoring_endpoint" {
  description = "Monitoring dashboard endpoint"
  value       = module.monitoring.dashboard_endpoint
}






