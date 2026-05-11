variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "East US"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "kubernetes_version" {
  description = "AKS Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "node_vm_size" {
  description = "VM size for the default node pool"
  type        = string
  default     = "Standard_B2s"
}

variable "node_min_count" {
  description = "Minimum number of nodes in the default pool"
  type        = number
  default     = 2
}

variable "node_max_count" {
  description = "Maximum number of nodes in the default pool"
  type        = number
  default     = 5
}

variable "api_server_authorized_ips" {
  description = "List of IPs allowed to reach the Kubernetes API server"
  type        = list(string)
  default     = []
}

# ── VNet variables ────────────────────────────────────────────────────────────

variable "vnet_address_space" {
  description = "CIDR block for YOUR company's VNet. Must NOT overlap with partner VNet."
  type        = string
  default     = "10.10.0.0/16"
}

variable "aks_subnet_cidr" {
  description = "CIDR for the AKS nodes subnet (must be inside vnet_address_space)"
  type        = string
  default     = "10.10.1.0/24"
}

variable "appgw_subnet_cidr" {
  description = "CIDR for the App Gateway subnet (must be inside vnet_address_space)"
  type        = string
  default     = "10.10.2.0/24"
}

# ── Partner VNet Peering variables ────────────────────────────────────────────

variable "partner_vnet_id" {
  description = "Full resource ID of the partner company's VNet. Get this from them. Format: /subscriptions/<id>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<name>"
  type        = string
}

variable "partner_vnet_name" {
  description = "Name of the partner company's VNet (used for peering resource naming)"
  type        = string
}

variable "partner_vnet_address_space" {
  description = "CIDR block of the partner VNet — used in NSG rule to allow their traffic in"
  type        = string
}

variable "partner_resource_group_name" {
  description = "Resource group name where the partner's VNet lives (only needed if same tenant)"
  type        = string
  default     = ""
}

variable "create_partner_peering" {
  description = <<-EOT
    Set to true if BOTH companies are in the same Azure tenant — Terraform will create
    the peering on both sides automatically.
    Set to false if different tenants — the partner must create their side manually.
  EOT
  type        = bool
  default     = false
}
