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
# Azure Container Registry.
#
# Name must be globally unique, 5-50 chars, alphanumeric only. We derive
# it from the env name with hyphens stripped.
# ---------------------------------------------------------------------------
resource "azurerm_container_registry" "this" {
  name                = replace("cr${var.name}", "-", "")
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.sku
  admin_enabled       = false
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Grant the AKS kubelet identity pull access on this registry.
#
# Without this, pods pulling images from the registry get:
#   Failed to pull image "<registry>.azurecr.io/...": 401 Unauthorized
#
# AcrPull is the least-privilege role for pulling only.
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "kubelet_acr_pull" {
  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPull"
  principal_id         = var.kubelet_identity_object_id

  # Managed identities can take a few seconds to propagate in Entra.
  # skip_service_principal_aad_check avoids a race where the role
  # assignment is created before the identity is queryable in AAD.
  skip_service_principal_aad_check = true
}

# ---------------------------------------------------------------------------
# Optional: grant a GitHub Actions workload identity push rights.
# Used in Task 2 when CI builds and pushes images. For Task 1 we push
# manually with `az acr login`, so leave the input null.
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "github_actions_acr_push" {
  count                = var.github_actions_enabled ? 1 : 0
  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPush"
  principal_id         = var.github_actions_principal_id

  skip_service_principal_aad_check = true
}
