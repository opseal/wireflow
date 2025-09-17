# Security Module for VPN Infrastructure

# Security Groups for AWS
resource "aws_security_group" "vpn_servers" {
  count       = var.cloud_provider == "aws" ? 1 : 0
  name        = "${var.cluster_name}-vpn-servers"
  description = "Security group for VPN servers"
  vpc_id      = var.vpc_id

  # WireGuard UDP traffic
  ingress {
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "WireGuard VPN traffic"
  }

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "SSH access"
  }

  # API access
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "VPN API access"
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-vpn-servers"
  })
}

resource "aws_security_group" "load_balancer" {
  count       = var.cloud_provider == "aws" ? 1 : 0
  name        = "${var.cluster_name}-lb"
  description = "Security group for load balancer"
  vpc_id      = var.vpc_id

  # HTTP traffic
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP traffic"
  }

  # HTTPS traffic
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS traffic"
  }

  # WireGuard UDP traffic
  ingress {
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "WireGuard VPN traffic"
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-load-balancer"
  })
}

# Network ACLs for additional security
resource "aws_network_acl" "vpn" {
  count      = var.cloud_provider == "aws" ? 1 : 0
  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  # Allow HTTP traffic
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  # Allow HTTPS traffic
  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Allow WireGuard traffic
  ingress {
    protocol   = "udp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 51820
    to_port    = 51820
  }

  # Allow SSH traffic
  ingress {
    protocol   = "tcp"
    rule_no    = 130
    action     = "allow"
    cidr_block = "10.0.0.0/8"
    from_port  = 22
    to_port    = 22
  }

  # Allow ephemeral ports
  ingress {
    protocol   = "tcp"
    rule_no    = 140
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Allow all outbound traffic
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-nacl"
  })
}

# WAF for API protection
resource "aws_wafv2_web_acl" "vpn_api" {
  count    = var.cloud_provider == "aws" ? 1 : 0
  name     = "${var.cluster_name}-api-waf"
  scope    = "REGIONAL"
  provider = aws.us-west-2

  default_action {
    allow {}
  }

  # Rate limiting rule
  rule {
    name     = "RateLimitRule"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRule"
      sampled_requests_enabled   = true
    }
  }

  # SQL injection protection
  rule {
    name     = "SQLInjectionRule"
    priority = 2

    action {
      block {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLInjectionRule"
      sampled_requests_enabled   = true
    }
  }

  # XSS protection
  rule {
    name     = "XSSRule"
    priority = 3

    action {
      block {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "XSSRule"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.cluster_name}-api-waf"
    sampled_requests_enabled   = true
  }

  tags = var.tags
}

# CloudTrail for audit logging
resource "aws_cloudtrail" "vpn" {
  count                         = var.cloud_provider == "aws" ? 1 : 0
  name                          = "${var.cluster_name}-cloudtrail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail[0].id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true

  event_selector {
    read_write_type                 = "All"
    include_management_events       = true
    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::"]
    }
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail[0]]

  tags = var.tags
}

resource "aws_s3_bucket" "cloudtrail" {
  count  = var.cloud_provider == "aws" ? 1 : 0
  bucket = "${var.cluster_name}-cloudtrail-${random_string.bucket_suffix[0].result}"

  tags = var.tags
}

resource "random_string" "bucket_suffix" {
  count   = var.cloud_provider == "aws" ? 1 : 0
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  count  = var.cloud_provider == "aws" ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail[0].arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail[0].arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# GuardDuty for threat detection
resource "aws_guardduty_detector" "vpn" {
  count  = var.cloud_provider == "aws" ? 1 : 0
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = var.tags
}

# Config for compliance monitoring
resource "aws_config_configuration_recorder" "vpn" {
  count    = var.cloud_provider == "aws" ? 1 : 0
  name     = "${var.cluster_name}-config-recorder"
  role_arn = aws_iam_role.config[0].arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }

  depends_on = [aws_config_delivery_channel.vpn[0]]
}

resource "aws_config_delivery_channel" "vpn" {
  count          = var.cloud_provider == "aws" ? 1 : 0
  name           = "${var.cluster_name}-config-delivery"
  s3_bucket_name = aws_s3_bucket.config[0].id
}

resource "aws_s3_bucket" "config" {
  count  = var.cloud_provider == "aws" ? 1 : 0
  bucket = "${var.cluster_name}-config-${random_string.bucket_suffix[0].result}"

  tags = var.tags
}

resource "aws_iam_role" "config" {
  count = var.cloud_provider == "aws" ? 1 : 0
  name  = "${var.cluster_name}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "config" {
  count      = var.cloud_provider == "aws" ? 1 : 0
  role       = aws_iam_role.config[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/ConfigRole"
}

# GCP Security
resource "google_compute_firewall" "vpn" {
  count   = var.cloud_provider == "gcp" ? 1 : 0
  name    = "${var.cluster_name}-vpn-firewall"
  network = google_compute_network.main[0].name
  project = var.gcp_project_id

  allow {
    protocol = "udp"
    ports    = ["51820"]
  }

  allow {
    protocol = "tcp"
    ports    = ["22", "8080", "80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["vpn-server"]

  depends_on = [google_project_service.compute]
}

# Azure Security
resource "azurerm_network_security_group" "vpn" {
  count               = var.cloud_provider == "azurerm" ? 1 : 0
  name                = "${var.cluster_name}-vpn-nsg"
  location            = var.region
  resource_group_name = azurerm_resource_group.main[0].name

  security_rule {
    name                       = "WireGuard"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "51820"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "SSH"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.0.0.0/8"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "API"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "10.0.0.0/8"
    destination_address_prefix = "*"
  }

  tags = var.tags
}






