# ---------------------------------------------------------------------------
# Prod environment composition.
#
# Structurally identical to staging — the task spec requires "modules
# reused for staging and prod, differing only by variables." The only
# differences here are: state key, CIDR, env name/tag, autoscale max,
# namespace. Any SKU bumps live in locals/vars, not in module source.
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

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name}"
  location = var.location
  tags     = local.tags
}

# ---------------------------------------------------------------------------
# Networking — 10.50.0.0/16 so prod and staging VNets never collide
# (and could peer in future without renumbering).
# ---------------------------------------------------------------------------

module "networking" {
  source = "../../modules/networking"

  name                = local.name
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  vnet_cidr            = "10.50.0.0/16"
  aks_subnet_cidr      = "10.50.0.0/20"
  db_subnet_cidr       = "10.50.16.0/24"
  services_subnet_cidr = "10.50.17.0/24"

  tags = local.tags
}

# ---------------------------------------------------------------------------
# AKS — same cluster shape as staging. SKU stays "Free" because the
# €200 total budget rules out the Standard tier (~€70/mo for the SLA).
# Autoscale max bumped to 5 so prod has more HPA headroom.
# ---------------------------------------------------------------------------

module "aks" {
  source = "../../modules/aks"

  name                = local.name
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  aks_subnet_id       = module.networking.aks_subnet_id

  tenant_id              = data.azurerm_client_config.current.tenant_id
  admin_group_object_ids = var.aks_admin_group_object_ids

  sku_tier            = "Free"
  system_node_vm_size = "Standard_B2s"
  system_node_count   = 1
  user_node_vm_size   = "Standard_B2s"
  user_node_min_count = 2
  user_node_max_count = 5

  tags = local.tags
}

module "registry" {
  source = "../../modules/registry"

  name                       = local.name
  location                   = var.location
  resource_group_name        = azurerm_resource_group.main.name
  sku                        = "Basic"
  kubelet_identity_object_id = module.aks.kubelet_identity_object_id

  tags = local.tags
}

module "database" {
  source = "../../modules/database"

  name                         = local.name
  location                     = var.location
  resource_group_name          = azurerm_resource_group.main.name
  db_subnet_id                 = module.networking.db_subnet_id
  postgres_private_dns_zone_id = module.networking.postgres_private_dns_zone_id

  tags = local.tags
}

module "identity" {
  source = "../../modules/identity"

  name                = local.name
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  oidc_issuer_url     = module.aks.oidc_issuer_url

  workloads = {
    shoplite = {
      namespace       = "shoplite-${local.env}"
      service_account = "shoplite"
    }
  }

  tags = local.tags
}
