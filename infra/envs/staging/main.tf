# ---------------------------------------------------------------------------
# Staging environment composition.
#
# Wires the five modules together into a complete environment.
# Nothing is created in Azure until `terraform apply` runs here.
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

  # Remote state in the Azure storage account created by scripts/bootstrap-tfstate.sh.
  # Backend blocks do not support variables — values hardcoded on purpose.
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

# Picks up the tenant ID + the currently logged-in principal (az login).
# Used so we never hardcode the tenant.
data "azurerm_client_config" "current" {}

# ---------------------------------------------------------------------------
# Env-level constants
# ---------------------------------------------------------------------------

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
# Resource group — the top-level container that holds everything.
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name}"
  location = var.location
  tags     = local.tags
}

# ---------------------------------------------------------------------------
# Networking — VNet, 3 subnets, Postgres private DNS zone.
# ---------------------------------------------------------------------------

module "networking" {
  source = "../../modules/networking"

  name                = local.name
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  # /16 per env. Prod will use 10.50.x.x so the two VNets could peer.
  vnet_cidr            = "10.40.0.0/16"
  aks_subnet_cidr      = "10.40.0.0/20"
  db_subnet_cidr       = "10.40.16.0/24"
  services_subnet_cidr = "10.40.17.0/24"

  tags = local.tags
}

# ---------------------------------------------------------------------------
# AKS — one cluster with system + user node pools, OIDC + Workload Identity.
# ---------------------------------------------------------------------------

module "aks" {
  source = "../../modules/aks"

  name                = local.name
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  aks_subnet_id       = module.networking.aks_subnet_id

  tenant_id              = data.azurerm_client_config.current.tenant_id
  admin_group_object_ids = var.aks_admin_group_object_ids

  # Staging — small and cheap. Prod will bump these.
  sku_tier            = "Free"
  system_node_vm_size = "Standard_B2s"
  system_node_count   = 1
  user_node_vm_size   = "Standard_B2s"
  user_node_min_count = 1
  user_node_max_count = 3

  tags = local.tags
}

# ---------------------------------------------------------------------------
# Registry — ACR + AcrPull for the AKS kubelet identity.
# ---------------------------------------------------------------------------

module "registry" {
  source = "../../modules/registry"

  name                       = local.name
  location                   = var.location
  resource_group_name        = azurerm_resource_group.main.name
  sku                        = "Basic"
  kubelet_identity_object_id = module.aks.kubelet_identity_object_id

  tags = local.tags
}

# ---------------------------------------------------------------------------
# Database — Postgres Flexible Server (VNet-integrated) + Redis Basic C0.
# ---------------------------------------------------------------------------

module "database" {
  source = "../../modules/database"

  name                         = local.name
  location                     = var.location
  resource_group_name          = azurerm_resource_group.main.name
  db_subnet_id                 = module.networking.db_subnet_id
  postgres_private_dns_zone_id = module.networking.postgres_private_dns_zone_id

  tags = local.tags
}

# ---------------------------------------------------------------------------
# Identity — UAMI + federated credentials for Workload Identity.
#
# One identity per Kubernetes ServiceAccount that will call Azure APIs.
# For staging we start with the shoplite workload only; External Secrets
# Operator will be added in Phase 5 as another map entry.
# ---------------------------------------------------------------------------

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
