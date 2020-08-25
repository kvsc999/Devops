resource  "azurerm_public_ip" "k8s" {
  name                    = "${random_pet.cluster.id}-ip"
  resource_group_name     = "${azurerm_resource_group.k8s.name}"
  location                = "${azurerm_resource_group.k8s.location}"
  allocation_method       = "Static"
  sku                     = "Standard"
  idle_timeout_in_minutes = 30
}

resource "azurerm_subnet" "k8s_frontend" {
  name                 = "${random_pet.cluster.id}-subnet-frontend"
  resource_group_name  = "${azurerm_resource_group.k8s.name}"
  virtual_network_name = "${azurerm_virtual_network.k8s_vnet.name}"
  address_prefix       = "10.1.2.0/24"
  service_endpoints    = [
    "Microsoft.KeyVault",
  ]
}

locals {
  backend_address_pool_name      = "${azurerm_virtual_network.k8s_vnet.name}-beap"
  frontend_port_name             = "${azurerm_virtual_network.k8s_vnet.name}-feport"
  frontend_ip_configuration_name = "${azurerm_virtual_network.k8s_vnet.name}-ip"
  http_setting_name              = "${azurerm_virtual_network.k8s_vnet.name}-be-htst"
  listener_name                  = "${azurerm_virtual_network.k8s_vnet.name}-httplstn"
  request_routing_rule_name      = "${azurerm_virtual_network.k8s_vnet.name}-rqrt"
  redirect_configuration_name    = "${azurerm_virtual_network.k8s_vnet.name}-rdrcfg"
}

resource "azurerm_application_gateway" "network" {
  name                = "${random_pet.cluster.id}-appgateway"
  resource_group_name = "${azurerm_resource_group.k8s.name}"
  location            = "${azurerm_resource_group.k8s.location}"

// Requires https://github.com/terraform-providers/terraform-provider-azurerm/pull/3648
  identity {
    type  = "UserAssigned"
    identity_ids = ["${azurerm_user_assigned_identity.k8s.id}"]
  }

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = "${azurerm_subnet.k8s_frontend.id}"
  }

  frontend_port {
    name = "${local.frontend_port_name}"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "${local.frontend_ip_configuration_name}"
    public_ip_address_id = "${azurerm_public_ip.k8s.id}"
  }

  backend_address_pool {
    name = "${local.backend_address_pool_name}"
  }

  backend_http_settings {
    name                  = "${local.http_setting_name}"
    cookie_based_affinity = "Disabled"
    path                  = "/path1/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 1
  }

  http_listener {
    name                           = "${local.listener_name}"
    frontend_ip_configuration_name = "${local.frontend_ip_configuration_name}"
    frontend_port_name             = "${local.frontend_port_name}"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                        = "${local.request_routing_rule_name}"
    rule_type                   = "Basic"
    http_listener_name          = "${local.listener_name}"
    backend_address_pool_name   = "${local.backend_address_pool_name}"
    backend_http_settings_name  = "${local.http_setting_name}"
  }
}

# Terraform must have Owner access to the resource group/subscription 
resource "azurerm_role_assignment" "k8s-ingress" {
  //scope                = "/subscriptions/${var.subscription}/resourceGroups/${random_pet.cluster.id}/providers/Microsoft.Network/applicationGateways/${random_pet.cluster.id}-appgateway"
  scope                = "${azurerm_application_gateway.network.id}"
  role_definition_name = "Contributor"
  principal_id         = "${azurerm_user_assigned_identity.k8s.principal_id}"
}
