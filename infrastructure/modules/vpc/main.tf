# VPC Module for VPN Infrastructure

# AWS VPC
resource "aws_vpc" "main" {
  count                = var.cloud_provider == "aws" ? 1 : 0
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-vpc"
  })
}

# AWS Internet Gateway
resource "aws_internet_gateway" "main" {
  count  = var.cloud_provider == "aws" ? 1 : 0
  vpc_id = aws_vpc.main[0].id

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-igw"
  })
}

# AWS Public Subnets
resource "aws_subnet" "public" {
  count                   = var.cloud_provider == "aws" ? length(var.availability_zones) : 0
  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-public-${count.index + 1}"
    Type = "Public"
  })
}

# AWS Private Subnets
resource "aws_subnet" "private" {
  count             = var.cloud_provider == "aws" ? length(var.availability_zones) : 0
  vpc_id            = aws_vpc.main[0].id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-private-${count.index + 1}"
    Type = "Private"
  })
}

# AWS NAT Gateway
resource "aws_eip" "nat" {
  count  = var.cloud_provider == "aws" ? 1 : 0
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-nat-eip"
  })
}

resource "aws_nat_gateway" "main" {
  count         = var.cloud_provider == "aws" ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-nat-gateway"
  })
}

# AWS Route Tables
resource "aws_route_table" "public" {
  count  = var.cloud_provider == "aws" ? 1 : 0
  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-public-rt"
  })
}

resource "aws_route_table" "private" {
  count  = var.cloud_provider == "aws" ? 1 : 0
  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[0].id
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-private-rt"
  })
}

# AWS Route Table Associations
resource "aws_route_table_association" "public" {
  count          = var.cloud_provider == "aws" ? length(aws_subnet.public) : 0
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table_association" "private" {
  count          = var.cloud_provider == "aws" ? length(aws_subnet.private) : 0
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}

# GCP VPC Network
resource "google_compute_network" "main" {
  count                   = var.cloud_provider == "gcp" ? 1 : 0
  name                    = "${var.cluster_name}-vpc"
  auto_create_subnetworks = false
  project                 = var.gcp_project_id

  depends_on = [google_project_service.compute]
}

resource "google_project_service" "compute" {
  count   = var.cloud_provider == "gcp" ? 1 : 0
  project = var.gcp_project_id
  service = "compute.googleapis.com"

  disable_dependent_services = true
}

# GCP Subnets
resource "google_compute_subnetwork" "main" {
  count         = var.cloud_provider == "gcp" ? 1 : 0
  name          = "${var.cluster_name}-subnet"
  ip_cidr_range = "10.0.0.0/16"
  region        = var.region
  network       = google_compute_network.main[0].id
  project       = var.gcp_project_id

  private_ip_google_access = true
}

# Azure Virtual Network
resource "azurerm_virtual_network" "main" {
  count               = var.cloud_provider == "azurerm" ? 1 : 0
  name                = "${var.cluster_name}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.region
  resource_group_name = azurerm_resource_group.main[0].name

  tags = var.tags
}

resource "azurerm_resource_group" "main" {
  count    = var.cloud_provider == "azurerm" ? 1 : 0
  name     = "${var.cluster_name}-rg"
  location = var.region

  tags = var.tags
}

resource "azurerm_subnet" "main" {
  count                = var.cloud_provider == "azurerm" ? 1 : 0
  name                 = "${var.cluster_name}-subnet"
  resource_group_name  = azurerm_resource_group.main[0].name
  virtual_network_name = azurerm_virtual_network.main[0].name
  address_prefixes     = ["10.0.1.0/24"]
}






