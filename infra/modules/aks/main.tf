terraform {
  required_version = ">= 1.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# ---------------------------------------------------------------------------
# User-assigned managed identity for the AKS control plane.
#
# AKS needs an identity to call Azure APIs (attach disks, create load
# balancers, etc.). We create our own instead of letting AKS auto-create
# a system-assigned one, so we can grant it roles explicitly and reuse it.
# ---------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "cluster" {
  name                = "id-aks-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# The AKS cluster itself.
# ---------------------------------------------------------------------------
resource "azurerm_kubernetes_cluster" "this" {
  name                = "aks-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "aks-${var.name}"
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier
  tags                = var.tags

  # OIDC issuer turns the cluster into an OpenID Connect provider.
  # Workload Identity (step 1.5) needs this so pods can get federated
  # tokens from Entra without any client secret.
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # Local kubeconfig admin accounts are disabled. All access flows through
  # Entra, which satisfies the "no long-lived credentials" principle.
  local_account_disabled = true

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    tenant_id          = var.tenant_id
    admin_group_object_ids = var.admin_group_object_ids
  }

  # System node pool — runs kube-system + Azure addons only. Taints push
  # app workloads to the user pool. Small SKU keeps cost down.
  default_node_pool {
    name                 = "system"
    vm_size              = var.system_node_vm_size
    node_count           = var.system_node_count
    vnet_subnet_id       = var.aks_subnet_id
    orchestrator_version = var.kubernetes_version
    only_critical_addons_enabled = true
    tags                 = var.tags
  }

  # Use the identity we created above instead of a system-assigned one.
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.cluster.id]
  }

  # Azure CNI Overlay — pods get IPs from an overlay network, not from
  # the AKS subnet. Avoids subnet exhaustion when scaling pod replicas.
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    load_balancer_sku   = "standard"
    pod_cidr            = var.pod_cidr
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip
  }

  # The identity the kubelet uses on each node — this is what we grant
  # AcrPull to in the registry module so nodes can pull images.
  kubelet_identity {
    client_id                 = azurerm_user_assigned_identity.kubelet.client_id
    object_id                 = azurerm_user_assigned_identity.kubelet.principal_id
    user_assigned_identity_id = azurerm_user_assigned_identity.kubelet.id
  }

  lifecycle {
    # kubernetes_version drifts as Azure rolls patches; don't fight it.
    ignore_changes = [kubernetes_version, default_node_pool[0].orchestrator_version]
  }
}

# ---------------------------------------------------------------------------
# Kubelet identity — separate from the cluster identity.
#
# Cluster identity  = used by the AKS control plane for Azure API calls.
# Kubelet identity  = used by nodes to pull from ACR, mount Key Vault
#                     secrets, etc. Separation of concerns.
# ---------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "kubelet" {
  name                = "id-aks-kubelet-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# The cluster identity needs permission to assign the kubelet identity
# to nodes. Without this role, cluster creation fails with a permissions
# error on the kubelet identity.
resource "azurerm_role_assignment" "cluster_identity_operator" {
  scope                = azurerm_user_assigned_identity.kubelet.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_user_assigned_identity.cluster.principal_id
}

# ---------------------------------------------------------------------------
# User node pool — where app workloads run. Separate from the system pool
# so we can scale and upgrade app capacity without touching kube-system.
# ---------------------------------------------------------------------------
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = var.user_node_vm_size
  vnet_subnet_id        = var.aks_subnet_id
  orchestrator_version  = var.kubernetes_version
  mode                  = "User"

  auto_scaling_enabled = true
  min_count            = var.user_node_min_count
  max_count            = var.user_node_max_count

  tags = var.tags

  lifecycle {
    ignore_changes = [orchestrator_version, node_count]
  }
}
