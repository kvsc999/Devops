provider "kubernetes"  {
    host                   = "${azurerm_kubernetes_cluster.k8s.kube_config.0.host}"
    client_certificate     = "${base64decode(azurerm_kubernetes_cluster.k8s.kube_config.0.client_certificate)}"
    client_key             = "${base64decode(azurerm_kubernetes_cluster.k8s.kube_config.0.client_key)}"
    cluster_ca_certificate = "${base64decode(azurerm_kubernetes_cluster.k8s.kube_config.0.cluster_ca_certificate)}"
}

resource "kubernetes_service_account" "tiller" {
  metadata {
    name      = "tiller"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding" "tiller" {
  metadata {
    name = "tiller"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  # api_group has to be empty because of a bug:
  # https://github.com/terraform-providers/terraform-provider-kubernetes/issues/204
  subject {
    api_group = ""
    kind      = "ServiceAccount"
    name      = "tiller"
    namespace = "kube-system"
  }
}

resource "azurerm_kubernetes_cluster" "k8s" {
  name                = "${random_pet.cluster.id}"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.k8s.name}"
  dns_prefix          = "${random_pet.cluster.id}"
  kubernetes_version  = "${var.kub_version}"

  linux_profile {
    admin_username = "ubuntu"

    ssh_key {
      key_data = "${file("${var.ssh_public_key}")}"
    }
  }

  network_profile {
    network_plugin = "azure"
  }

  agent_pool_profile {
    name            = "default"
    count           = "${var.agent_count}"
    vm_size         = "Standard_B2s"
    os_type         = "Linux"
    os_disk_size_gb = 30
    vnet_subnet_id  = "${azurerm_subnet.k8s_subnet.id}"
  }

  service_principal {
    client_id     = "${var.client_id}"
    client_secret = "${var.client_secret}"
  }

  role_based_access_control {
    enabled = true
  }

  addon_profile {
    oms_agent {
      enabled                    = true
      log_analytics_workspace_id = "${azurerm_log_analytics_workspace.k8s.id}"
    }
  }

  tags {
    Environment = "Production"
  }
}