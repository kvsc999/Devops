resource "azurerm_key_vault" "test" {
  name                        = "${random_pet.cluster.id}"
  location                    = "${azurerm_resource_group.k8s.location}"
  resource_group_name         = "${azurerm_resource_group.k8s.name}"
  tenant_id                   = "${var.tenant_id}"

  sku {
    name = "standard"
  }

  access_policy {
    tenant_id = "${var.tenant_id}"
    object_id = "${azurerm_user_assigned_identity.k8s.principal_id}"

    key_permissions = [
      "get",
    ]

    secret_permissions = [
      "get",
    ]

    storage_permissions = [
      "get",
    ]

    certificate_permissions = [
      "get",
      "list",
      "import",
    ]
  }

  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = [
        "${azurerm_subnet.k8s_frontend.id}",
    ]
  }

}