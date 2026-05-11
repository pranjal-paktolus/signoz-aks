locals {
  tags = {
    environment = var.environment
    project     = "aks-gitops"
    owner       = "platform-team"
    managed_by  = "terraform"
    workload    = "signoz"
  }
}

resource "azurerm_resource_group" "rg" {
  name     = "aks-gitops-${var.environment}-rg"
  location = var.location
  tags     = local.tags
}

resource "azurerm_log_analytics_workspace" "logs" {
  name                = "aks-logs-${var.environment}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

resource "azurerm_virtual_network" "vnet" {
  name                = "aks-gitops-${var.environment}-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = [var.vnet_address_space]
  tags                = local.tags
}

resource "azurerm_subnet" "aks" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.aks_subnet_cidr]
}

resource "azurerm_subnet" "appgw" {
  name                 = "appgw-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.appgw_subnet_cidr]
}

resource "azurerm_network_security_group" "aks_nsg" {
  name                = "aks-${var.environment}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags

  dynamic "security_rule" {
    for_each = var.enable_partner_peering ? [1] : []
    content {
      name                       = "allow-partner-vnet-inbound"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = var.partner_vnet_address_space
      destination_address_prefix = var.aks_subnet_cidr
    }
  }

  security_rule {
    name                       = "allow-vnet-inbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "deny-all-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "aks_nsg" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks_nsg.id
}

resource "azurerm_virtual_network_peering" "to_partner" {
  count = var.enable_partner_peering ? 1 : 0

  name                      = "peer-to-${var.partner_vnet_name}"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet.name
  remote_virtual_network_id = var.partner_vnet_id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "from_partner" {
  count = var.enable_partner_peering && var.create_partner_peering ? 1 : 0

  name                      = "peer-to-${azurerm_virtual_network.vnet.name}"
  resource_group_name       = var.partner_resource_group_name
  virtual_network_name      = var.partner_vnet_name
  remote_virtual_network_id = azurerm_virtual_network.vnet.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_container_registry" "acr" {
  name                = "aksgitops${var.environment}acr"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard"
  admin_enabled       = false
  tags                = local.tags
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                             = "gitops-aks-${var.environment}"
  location                         = azurerm_resource_group.rg.location
  resource_group_name              = azurerm_resource_group.rg.name
  dns_prefix                       = "gitopsaks${var.environment}"
  kubernetes_version               = var.kubernetes_version
  local_account_disabled           = true
  automatic_channel_upgrade        = "stable"
  node_os_channel_upgrade          = "NodeImage"
  http_application_routing_enabled = false
  tags                             = local.tags

  default_node_pool {
    name                = "default"
    vm_size             = var.node_vm_size
    enable_auto_scaling = true
    min_count           = var.node_min_count
    max_count           = var.node_max_count
    os_disk_size_gb     = 128
    vnet_subnet_id      = azurerm_subnet.aks.id
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
  }

  ingress_application_gateway {
    gateway_name = "aks-appgw-${var.environment}"
    subnet_id    = azurerm_subnet.appgw.id
  }

  azure_active_directory_role_based_access_control {
    managed                = true
    admin_group_object_ids = var.admin_group_object_ids
  }

  api_server_access_profile {
    authorized_ip_ranges = var.api_server_authorized_ips
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.id
  }

  microsoft_defender {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.id
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  storage_profile {
    blob_driver_enabled         = true
    disk_driver_enabled         = true
    file_driver_enabled         = true
    snapshot_controller_enabled = true
  }

  maintenance_window {
    allowed {
      day   = "Sunday"
      hours = [2, 3]
    }
  }

  depends_on = [azurerm_subnet_network_security_group_association.aks_nsg]
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}

resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "aks-diagnostics"
  target_resource_id         = azurerm_kubernetes_cluster.aks.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.id

  enabled_log { category = "kube-apiserver" }
  enabled_log { category = "kube-audit" }
  enabled_log { category = "kube-audit-admin" }
  enabled_log { category = "kube-controller-manager" }
  enabled_log { category = "kube-scheduler" }
  enabled_log { category = "guard" }

  metric { category = "AllMetrics" }
}

resource "azurerm_kubernetes_cluster_node_pool" "spot" {
  name                  = "spot"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = var.node_vm_size
  priority              = "Spot"
  eviction_policy       = "Delete"
  spot_max_price        = -1
  enable_auto_scaling   = true
  min_count             = 0
  max_count             = 3
  os_disk_size_gb       = 128
  vnet_subnet_id        = azurerm_subnet.aks.id
  tags                  = local.tags
}
