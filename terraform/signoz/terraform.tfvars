location                  = "East US 2"
environment               = "signoz"
kubernetes_version        = "1.33.7"
node_min_count            = 2
node_max_count            = 4
node_vm_size              = "Standard_D4_v3"
api_server_authorized_ips = []
admin_group_object_ids    = ["64dd7ab2-7110-4131-a882-1aa2ab007e5a"]

vnet_address_space = "10.30.0.0/16"
aks_subnet_cidr    = "10.30.1.0/24"
appgw_subnet_cidr  = "10.30.2.0/24"

partner_vnet_id             = ""
partner_vnet_name           = ""
partner_vnet_address_space  = ""
enable_partner_peering      = false
create_partner_peering      = false
partner_resource_group_name = ""
