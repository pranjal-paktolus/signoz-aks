location                  = "East US"
environment               = "dev"
node_min_count            = 2
node_max_count            = 5
node_vm_size              = "Standard_B2s"
api_server_authorized_ips = ["YOUR_OFFICE_IP/32"]

# ── YOUR VNet ─────────────────────────────────────────────────────────────────
vnet_address_space = "10.10.0.0/16"   # change if this conflicts with your network
aks_subnet_cidr    = "10.10.1.0/24"
appgw_subnet_cidr  = "10.10.2.0/24"

# ── Partner VNet Peering ──────────────────────────────────────────────────────
# Ask the partner company for these values:

partner_vnet_id = "/subscriptions/PARTNER_SUBSCRIPTION_ID/resourceGroups/PARTNER_RG/providers/Microsoft.Network/virtualNetworks/PARTNER_VNET_NAME"

partner_vnet_name          = "PARTNER_VNET_NAME"
partner_vnet_address_space = "10.20.0.0/16"   # partner's CIDR — must NOT overlap with yours

# Same Azure tenant as partner? → true (Terraform handles both sides)
# Different Azure tenant?       → false (partner applies their side manually)
create_partner_peering = false

# Only needed if create_partner_peering = true:
partner_resource_group_name = ""
