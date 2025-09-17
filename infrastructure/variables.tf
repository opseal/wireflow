# Input Variables

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
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
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
  validation {
    condition     = var.node_count >= 1 && var.node_count <= 10
    error_message = "Node count must be between 1 and 10."
  }
}

variable "instance_type" {
  description = "Instance type for worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "gcp_project_id" {
  description = "GCP Project ID (required for GCP)"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Domain name for VPN services"
  type        = string
  default     = ""
}

variable "enable_monitoring" {
  description = "Enable monitoring and logging"
  type        = bool
  default     = true
}

variable "enable_backup" {
  description = "Enable automated backups"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30
  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 365
    error_message = "Backup retention days must be between 1 and 365."
  }
}

variable "vpn_cidr" {
  description = "CIDR block for VPN network"
  type        = string
  default     = "10.0.0.0/24"
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access VPN"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}






