output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.openclaw.name
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.openclaw.name
}

output "aks_cluster_id" {
  description = "ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.openclaw.id
}

output "aks_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.openclaw.fqdn
}

output "aks_node_resource_group" {
  description = "Auto-generated resource group for AKS nodes"
  value       = azurerm_kubernetes_cluster.openclaw.node_resource_group
}

output "acr_login_server" {
  description = "Login server for Azure Container Registry"
  value       = azurerm_container_registry.openclaw.login_server
}

output "acr_id" {
  description = "ID of the Azure Container Registry"
  value       = azurerm_container_registry.openclaw.id
}

output "kube_config" {
  description = "Kubernetes configuration (sensitive)"
  value       = azurerm_kubernetes_cluster.openclaw.kube_config_raw
  sensitive   = true
}

output "get_credentials_command" {
  description = "Command to get AKS credentials"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.openclaw.name} --name ${azurerm_kubernetes_cluster.openclaw.name}"
}

output "total_nodes" {
  description = "Total number of nodes across all pools"
  value       = "System: 3, Production: 8, Compute: 5, Memory: 4 = Total 20 nodes"
}

output "node_pools" {
  description = "Summary of node pools"
  value = {
    system = {
      vm_size    = "Standard_D2s_v3"
      node_count = 3
      purpose    = "System workloads"
    }
    production = {
      vm_size    = "Standard_D4s_v3"
      node_count = "8 (autoscale: 5-12)"
      purpose    = "OpenClaw application workloads"
    }
    compute = {
      vm_size    = "Standard_F8s_v2"
      node_count = "5 (autoscale: 3-8)"
      purpose    = "AI processing and compute-intensive tasks"
    }
    memory = {
      vm_size    = "Standard_E4s_v3"
      node_count = "4 (autoscale: 2-6)"
      purpose    = "Memory-intensive data processing"
    }
  }
}
