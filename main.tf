terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "openclaw" {
  name     = var.resource_group_name
  location = var.location
  
  tags = {
    Environment = var.environment
    Project     = "OpenClaw"
    ManagedBy   = "Terraform"
  }
}

# Virtual Network
resource "azurerm_virtual_network" "openclaw" {
  name                = "${var.cluster_name}-vnet"
  location            = azurerm_resource_group.openclaw.location
  resource_group_name = azurerm_resource_group.openclaw.name
  address_space       = ["10.0.0.0/16"]
  
  tags = azurerm_resource_group.openclaw.tags
}

# Subnet for AKS
resource "azurerm_subnet" "aks" {
  name                 = "${var.cluster_name}-aks-subnet"
  resource_group_name  = azurerm_resource_group.openclaw.name
  virtual_network_name = azurerm_virtual_network.openclaw.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Log Analytics Workspace for monitoring
resource "azurerm_log_analytics_workspace" "openclaw" {
  name                = "${var.cluster_name}-logs"
  location            = azurerm_resource_group.openclaw.location
  resource_group_name = azurerm_resource_group.openclaw.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  
  tags = azurerm_resource_group.openclaw.tags
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "openclaw" {
  name                = var.cluster_name
  location            = azurerm_resource_group.openclaw.location
  resource_group_name = azurerm_resource_group.openclaw.name
  dns_prefix          = var.cluster_name
  kubernetes_version  = var.kubernetes_version
  
  # System node pool (required - 3 nodes for control plane workloads)
  default_node_pool {
    name                = "system"
    node_count          = 3
    vm_size             = "Standard_D2s_v3"  # 2 vCPU, 8GB RAM
    type                = "VirtualMachineScaleSets"
    vnet_subnet_id      = azurerm_subnet.aks.id
    enable_auto_scaling = false
    
    node_labels = {
      "nodepool-type" = "system"
      "environment"   = var.environment
      "nodepoolos"    = "linux"
    }
    
    tags = azurerm_resource_group.openclaw.tags
  }
  
  # Identity
  identity {
    type = "SystemAssigned"
  }
  
  # Network Profile
  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    network_policy    = "azure"
  }
  
  # Add-ons
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.openclaw.id
  }
  
  tags = azurerm_resource_group.openclaw.tags
}

# Production Node Pool - 8 nodes (Standard_D4s_v3: 4 vCPU, 16GB RAM)
resource "azurerm_kubernetes_cluster_node_pool" "production" {
  name                  = "production"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.openclaw.id
  vm_size               = "Standard_D4s_v3"
  node_count            = 8
  vnet_subnet_id        = azurerm_subnet.aks.id
  enable_auto_scaling   = true
  min_count             = 5
  max_count             = 12
  
  node_labels = {
    "nodepool-type" = "production"
    "workload"      = "openclaw-app"
  }
  
  node_taints = []
  
  tags = azurerm_resource_group.openclaw.tags
}

# Compute-Intensive Node Pool - 5 nodes (Standard_F8s_v2: 8 vCPU, 16GB RAM - optimized for compute)
resource "azurerm_kubernetes_cluster_node_pool" "compute" {
  name                  = "compute"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.openclaw.id
  vm_size               = "Standard_F8s_v2"
  node_count            = 5
  vnet_subnet_id        = azurerm_subnet.aks.id
  enable_auto_scaling   = true
  min_count             = 3
  max_count             = 8
  
  node_labels = {
    "nodepool-type" = "compute"
    "workload"      = "ai-processing"
  }
  
  tags = azurerm_resource_group.openclaw.tags
}

# Memory-Optimized Node Pool - 4 nodes (Standard_E4s_v3: 4 vCPU, 32GB RAM)
resource "azurerm_kubernetes_cluster_node_pool" "memory" {
  name                  = "memory"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.openclaw.id
  vm_size               = "Standard_E4s_v3"
  node_count            = 4
  vnet_subnet_id        = azurerm_subnet.aks.id
  enable_auto_scaling   = true
  min_count             = 2
  max_count             = 6
  
  node_labels = {
    "nodepool-type" = "memory"
    "workload"      = "data-intensive"
  }
  
  tags = azurerm_resource_group.openclaw.tags
}

# Role Assignment for AKS to manage network
resource "azurerm_role_assignment" "aks_network" {
  scope                = azurerm_virtual_network.openclaw.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.openclaw.identity[0].principal_id
}

# Azure Container Registry (optional but recommended)
resource "azurerm_container_registry" "openclaw" {
  name                = replace("${var.cluster_name}acr", "-", "")
  resource_group_name = azurerm_resource_group.openclaw.name
  location            = azurerm_resource_group.openclaw.location
  sku                 = "Standard"
  admin_enabled       = false
  
  tags = azurerm_resource_group.openclaw.tags
}

# Grant AKS pull access to ACR
resource "azurerm_role_assignment" "aks_acr" {
  scope                = azurerm_container_registry.openclaw.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.openclaw.kubelet_identity[0].object_id
}
