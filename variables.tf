variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
  default     = "openclaw-rg"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "openclaw-aks"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "production"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28.0"  # Update to latest stable version
}

variable "enable_autoscaling" {
  description = "Enable autoscaling for node pools"
  type        = bool
  default     = true
}

variable "team_assignments" {
  description = "Team assignments for OpenClaw instances"
  type = map(object({
    name        = string
    namespace   = string
    replicas    = number
    node_selector = map(string)
  }))
  default = {
    "team-alpha" = {
      name          = "alpha"
      namespace     = "openclaw-alpha"
      replicas      = 3
      node_selector = { "workload" = "openclaw-app" }
    }
    "team-beta" = {
      name          = "beta"
      namespace     = "openclaw-beta"
      replicas      = 3
      node_selector = { "workload" = "openclaw-app" }
    }
    "team-gamma" = {
      name          = "gamma"
      namespace     = "openclaw-gamma"
      replicas      = 2
      node_selector = { "workload" = "ai-processing" }
    }
  }
}
