# ---------------------------------------------------------------------------
# Staging environment — the per-env resources.
#
# Depends on shared (VNet, AKS, ACR, DNS zone). This composition only
# creates the per-env RG + Postgres + Redis + Workload Identity for the
# shoplite ServiceAccount in the shoplite-staging namespace.
# ---------------------------------------------------------------------------

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

  backend "azurerm" {
    resource_group_name  = "rg-tfstate-shoplite"
    storage_account_name = "tfstateshoplite3e4b93a6"
    container_name       = "tfstate"
    key                  = "staging.tfstate"
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}

# ---------------------------------------------------------------------------
# Read outputs from the shared composition.
# ---------------------------------------------------------------------------

data "terraform_remote_state" "shared" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-tfstate-shoplite"
    storage_account_name = "tfstateshoplite3e4b93a6"
    container_name       = "tfstate"
    key                  = "shared.tfstate"
    use_azuread_auth     = true
  }
}

data "azurerm_client_config" "current" {}

locals {
  env  = "staging"
  name = "shoplite-${local.env}"

  tags = {
    owner = "pavan"
    task  = "1"
    env   = local.env
  }
}

# ---------------------------------------------------------------------------
# Per-env RG — holds the DB, Redis, and Workload Identity for this env.
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "env" {
  name     = "rg-${local.name}"
  location = var.location
  tags     = local.tags
}

# ---------------------------------------------------------------------------
# Database — Postgres into the shared VNet's db-staging subnet.
# ---------------------------------------------------------------------------

module "database" {
  source = "../../modules/database"

  name                         = local.name
  location                     = var.location
  resource_group_name          = azurerm_resource_group.env.name
  db_subnet_id                 = data.terraform_remote_state.shared.outputs.db_subnet_ids[local.env]
  postgres_private_dns_zone_id = data.terraform_remote_state.shared.outputs.postgres_private_dns_zone_id

  tags = local.tags
}

# ---------------------------------------------------------------------------
# Identity — one UAMI federated to the shoplite SA in the shoplite-staging
# namespace, trusted via the shared AKS cluster's OIDC issuer.
# ---------------------------------------------------------------------------

module "identity" {
  source = "../../modules/identity"

  name                = local.name
  location            = var.location
  resource_group_name = azurerm_resource_group.env.name
  oidc_issuer_url     = data.terraform_remote_state.shared.outputs.aks_oidc_issuer_url

  workloads = {
    shoplite = {
      namespace       = "shoplite-${local.env}"
      service_account = "shoplite"
    }
  }

  tags = local.tags
}

# Env-scoped Key Vault — holds secrets ESO syncs into the shoplite namespace.
module "key_vault" {
  source = "../../modules/key_vault"

  name                  = local.name
  location              = var.location
  resource_group_name   = azurerm_resource_group.env.name
  tenant_id             = data.azurerm_client_config.current.tenant_id
  deployer_object_id    = data.azurerm_client_config.current.object_id
  workload_principal_id = module.identity.workload_identity_principal_ids["shoplite"]

  # KV secret names must be alphanumeric + dashes. The ExternalSecret CR
  # (in the shoplite chart) remaps `database-url` → env var DATABASE_URL.
  secrets = {
    "database-url" = module.database.postgres_connection_string
  }

  tags = local.tags
}
