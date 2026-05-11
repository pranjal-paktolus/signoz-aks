variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "East US 2"
}

variable "environment" {
  description = "Deployment environment name for the dedicated SigNoz AKS"
  type        = string
  default     = "signoz"
}

variable "kubernetes_version" {
  description = "AKS Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "node_vm_size" {
  description = "VM size for the default node pool"
  type        = string
  default     = "Standard_D4s_v5"
}

variable "node_min_count" {
  description = "Minimum number of nodes in the default pool"
  type        = number
  default     = 3
}

variable "node_max_count" {
  description = "Maximum number of nodes in the default pool"
  type        = number
  default     = 6
}

variable "api_server_authorized_ips" {
  description = "List of IPs allowed to reach the Kubernetes API server"
  type        = list(string)
  default     = []
}

variable "vnet_address_space" {
  description = "CIDR block for the dedicated SigNoz VNet"
  type        = string
  default     = "10.30.0.0/16"
}

variable "aks_subnet_cidr" {
  description = "CIDR for the SigNoz AKS nodes subnet"
  type        = string
  default     = "10.30.1.0/24"
}

variable "appgw_subnet_cidr" {
  description = "CIDR for the SigNoz App Gateway subnet"
  type        = string
  default     = "10.30.2.0/24"
}

variable "partner_vnet_id" {
  description = "Optional remote VNet resource ID if peering is required"
  type        = string
  default     = ""
}

variable "partner_vnet_name" {
  description = "Optional remote VNet name if peering is required"
  type        = string
  default     = ""
}

variable "partner_vnet_address_space" {
  description = "Optional remote VNet CIDR if peering is required"
  type        = string
  default     = ""
}

variable "partner_resource_group_name" {
  description = "Remote VNet resource group when same-tenant peering is required"
  type        = string
  default     = ""
}

variable "create_partner_peering" {
  description = "Whether to create the partner side of the VNet peering"
  type        = bool
  default     = false
}

variable "enable_partner_peering" {
  description = "Whether to create any partner VNet peering for the dedicated SigNoz AKS"
  type        = bool
  default     = false
}

variable "admin_group_object_ids" {
  description = "List of Entra group object IDs that should have AKS admin access"
  type        = list(string)
  default     = []
}
