# Kubernetes Cluster Module

# AWS EKS Cluster
resource "aws_eks_cluster" "main" {
  count    = var.cloud_provider == "aws" ? 1 : 0
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster[0].arn
  version  = "1.28"

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy[0],
    aws_cloudwatch_log_group.eks_cluster[0],
  ]

  tags = var.tags
}

# AWS EKS Node Group
resource "aws_eks_node_group" "main" {
  count           = var.cloud_provider == "aws" ? 1 : 0
  cluster_name    = aws_eks_cluster.main[0].name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = aws_iam_role.eks_node[0].arn
  subnet_ids      = var.subnet_ids
  instance_types  = [var.instance_type]

  scaling_config {
    desired_size = var.node_count
    max_size     = var.node_count * 2
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy[0],
    aws_iam_role_policy_attachment.eks_cni_policy[0],
    aws_iam_role_policy_attachment.eks_container_registry_policy[0],
  ]

  tags = var.tags
}

# AWS IAM Role for EKS Cluster
resource "aws_iam_role" "eks_cluster" {
  count = var.cloud_provider == "aws" ? 1 : 0
  name  = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })

  tags = var.tags
}

# AWS IAM Role for EKS Nodes
resource "aws_iam_role" "eks_node" {
  count = var.cloud_provider == "aws" ? 1 : 0
  name  = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })

  tags = var.tags
}

# AWS IAM Role Policy Attachments
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  count      = var.cloud_provider == "aws" ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster[0].name
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  count      = var.cloud_provider == "aws" ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node[0].name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  count      = var.cloud_provider == "aws" ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node[0].name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
  count      = var.cloud_provider == "aws" ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node[0].name
}

# AWS CloudWatch Log Group
resource "aws_cloudwatch_log_group" "eks_cluster" {
  count             = var.cloud_provider == "aws" ? 1 : 0
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 7

  tags = var.tags
}

# GCP GKE Cluster
resource "google_container_cluster" "main" {
  count      = var.cloud_provider == "gcp" ? 1 : 0
  name       = var.cluster_name
  location   = var.region
  project    = var.gcp_project_id
  network    = google_compute_network.main[0].name
  subnetwork = google_compute_subnetwork.main[0].name

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  network_policy {
    enabled = true
  }

  addons_config {
    network_policy_config {
      disabled = false
    }
  }

  depends_on = [google_project_service.compute]
}

# GCP GKE Node Pool
resource "google_container_node_pool" "main" {
  count      = var.cloud_provider == "gcp" ? 1 : 0
  name       = "${var.cluster_name}-nodes"
  location   = var.region
  cluster    = google_container_cluster.main[0].name
  project    = var.gcp_project_id
  node_count = var.node_count

  node_config {
    preemptible  = false
    machine_type = var.instance_type

    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only",
    ]

    metadata = {
      disable-legacy-endpoints = "true"
    }

    labels = var.tags

    tags = ["gke-node", "${var.cluster_name}-node"]
  }

  autoscaling {
    min_node_count = 1
    max_node_count = var.node_count * 2
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# Azure AKS Cluster
resource "azurerm_kubernetes_cluster" "main" {
  count               = var.cloud_provider == "azurerm" ? 1 : 0
  name                = var.cluster_name
  location            = var.region
  resource_group_name = azurerm_resource_group.main[0].name
  dns_prefix          = var.cluster_name
  kubernetes_version  = "1.28.0"

  default_node_pool {
    name       = "default"
    node_count = var.node_count
    vm_size    = var.instance_type
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"
  }

  tags = var.tags
}

# Azure Resource Group
resource "azurerm_resource_group" "main" {
  count    = var.cloud_provider == "azurerm" ? 1 : 0
  name     = "${var.cluster_name}-rg"
  location = var.region

  tags = var.tags
}

# Load Balancer for VPN
resource "aws_lb" "vpn" {
  count              = var.cloud_provider == "aws" ? 1 : 0
  name               = "${var.cluster_name}-vpn-lb"
  internal           = false
  load_balancer_type = "network"
  subnets            = var.subnet_ids

  enable_deletion_protection = false

  tags = var.tags
}

resource "aws_lb_target_group" "vpn" {
  count    = var.cloud_provider == "aws" ? 1 : 0
  name     = "${var.cluster_name}-vpn-tg"
  port     = 51820
  protocol = "UDP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 10
    interval            = 30
    port                = "traffic-port"
    protocol            = "UDP"
  }

  tags = var.tags
}

resource "aws_lb_listener" "vpn" {
  count             = var.cloud_provider == "aws" ? 1 : 0
  load_balancer_arn = aws_lb.vpn[0].arn
  port              = "51820"
  protocol          = "UDP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vpn[0].arn
  }
}






