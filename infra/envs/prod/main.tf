# ---------------------------------------------------------------------------
# Prod environment — mirror of staging with different env tag + namespace.
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
    key                  = "prod.tfstate"
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
  env  = "prod"
  name = "shoplite-${local.env}"

  tags = {
    owner = "pavan"
    task  = "1"
    env   = local.env
  }
}

resource "azurerm_resource_group" "env" {
  name     = "rg-${local.name}"
  location = var.location
  tags     = local.tags
}

module "database" {
  source = "../../modules/database"

  name                         = local.name
  location                     = var.location
  resource_group_name          = azurerm_resource_group.env.name
  db_subnet_id                 = data.terraform_remote_state.shared.outputs.db_subnet_ids[local.env]
  postgres_private_dns_zone_id = data.terraform_remote_state.shared.outputs.postgres_private_dns_zone_id

  # General-Purpose SKU for prod — Burstable B1ms hit RegionalAllocationFailed
  # in swedencentral. GP_Standard_D2s_v3 is the same family as our AKS nodes,
  # which are proven to have capacity here.
  postgres_sku_name = "GP_Standard_D2s_v3"

  tags = local.tags
}

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

module "key_vault" {
  source = "../../modules/key_vault"

  name                  = local.name
  location              = var.location
  resource_group_name   = azurerm_resource_group.env.name
  tenant_id             = data.azurerm_client_config.current.tenant_id
  deployer_object_id    = data.azurerm_client_config.current.object_id
  workload_principal_id = module.identity.workload_identity_principal_ids["shoplite"]

  secrets = {
    "database-url" = module.database.postgres_connection_string
  }

  tags = local.tags
}
