terraform {
  required_version = ">= 1.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# Random 4-char suffix so vault names stay globally unique across teardowns
# (Key Vault names get soft-deleted and block re-creation for 7 days).
resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
  numeric = true
}

resource "azurerm_key_vault" "this" {
  name                = "kv-${var.name}-${random_string.suffix.result}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id

  sku_name                   = "standard"
  rbac_authorization_enabled = true
  purge_protection_enabled   = false
  soft_delete_retention_days = 7

  tags = var.tags
}

# The person running Terraform needs write perms to seed secrets below.
resource "azurerm_role_assignment" "deployer_admin" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.deployer_object_id
}

# The workload identity needs read perms for ESO to sync secrets into K8s.
resource "azurerm_role_assignment" "workload_reader" {
  scope                            = azurerm_key_vault.this.id
  role_definition_name             = "Key Vault Secrets User"
  principal_id                     = var.workload_principal_id
  skip_service_principal_aad_check = true
}

# Seed each secret from the input map. Keys drive the loop; values are
# looked up at render time to keep sensitive data out of resource addresses.
resource "azurerm_key_vault_secret" "this" {
  for_each = toset(nonsensitive(keys(var.secrets)))

  name         = each.key
  value        = var.secrets[each.key]
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [azurerm_role_assignment.deployer_admin]
}
