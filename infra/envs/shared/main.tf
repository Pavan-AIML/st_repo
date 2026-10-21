# ---------------------------------------------------------------------------
# SHARED composition — the one-cluster platform.
#
# Builds: shared VNet (with per-env DB subnets), one AKS cluster, one ACR,
# one Postgres private DNS zone, and installs Argo CD into the cluster.
# Each env's staging/prod composition reads this via remote_state.
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.7"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.14"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.33"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-tfstate-shoplite"
    storage_account_name = "tfstateshoplite3e4b93a6"
    container_name       = "tfstate"
    key                  = "shared.tfstate"
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

data "azurerm_client_config" "current" {}

# ---------------------------------------------------------------------------
# Helm + Kubernetes providers — point at the AKS cluster we're about to
# create. Auth via kubelogin + Azure CLI token (your `az login` identity).
# Requires `kubelogin` installed locally: brew install Azure/kubelogin/kubelogin
# ---------------------------------------------------------------------------

provider "helm" {
  kubernetes {
    host                   = module.aks.cluster_host
    cluster_ca_certificate = base64decode(module.aks.cluster_ca_certificate)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "kubelogin"
      args = [
        "get-token",
        "--login", "azurecli",
        "--server-id", "6dae42f8-4368-4678-94ff-3960e28e3630",
      ]
    }
  }
}

provider "kubernetes" {
  host                   = module.aks.cluster_host
  cluster_ca_certificate = base64decode(module.aks.cluster_ca_certificate)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "kubelogin"
    args = [
      "get-token",
      "--login", "azurecli",
      "--server-id", "6dae42f8-4368-4678-94ff-3960e28e3630",
    ]
  }
}

# ---------------------------------------------------------------------------
# Shared platform constants
# ---------------------------------------------------------------------------

locals {
  name = "shoplite"

  tags = {
    owner = "pavan"
    task  = "1"
    env   = "shared"
  }
}

# Shared RG holds the VNet + AKS + ACR + DNS zone.
resource "azurerm_resource_group" "shared" {
  name     = "rg-${local.name}-shared"
  location = var.location
  tags     = local.tags
}

# ---------------------------------------------------------------------------
# Networking — shared VNet with per-env DB subnets inside it.
# ---------------------------------------------------------------------------

module "networking" {
  source = "../../modules/networking"

  name                = local.name
  location            = var.location
  resource_group_name = azurerm_resource_group.shared.name

  vnet_cidr            = "10.40.0.0/16"
  aks_subnet_cidr      = "10.40.0.0/20"
  services_subnet_cidr = "10.40.17.0/24"
  db_subnet_cidrs = {
    staging = "10.40.18.0/24"
    prod    = "10.40.19.0/24"
  }

  tags = local.tags
}

# ---------------------------------------------------------------------------
# AKS — one shared cluster.
# ---------------------------------------------------------------------------

module "aks" {
  source = "../../modules/aks"

  name                = local.name
  location            = var.location
  resource_group_name = azurerm_resource_group.shared.name
  aks_subnet_id       = module.networking.aks_subnet_id

  tenant_id              = data.azurerm_client_config.current.tenant_id
  admin_group_object_ids = var.aks_admin_group_object_ids

  sku_tier            = "Free"
  system_node_vm_size = "Standard_B2s"
  system_node_count   = 1
  user_node_vm_size   = "Standard_B2s"
  user_node_min_count = 1
  user_node_max_count = 3

  tags = local.tags
}

# ---------------------------------------------------------------------------
# Registry — one shared ACR.
# ---------------------------------------------------------------------------

module "registry" {
  source = "../../modules/registry"

  name                       = local.name
  location                   = var.location
  resource_group_name        = azurerm_resource_group.shared.name
  sku                        = "Basic"
  kubelet_identity_object_id = module.aks.kubelet_identity_object_id

  tags = local.tags
}

# ---------------------------------------------------------------------------
# Argo CD — installed into the shared cluster.
# From here on, everything is deployed by GitOps (gitops/apps/*).
# ---------------------------------------------------------------------------

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }

  depends_on = [module.aks]
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "7.6.12"
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  # Keep install minimal — HA/notifications/ApplicationSet default off.
  values = [
    yamlencode({
      global = {
        logging = { format = "json" }
      }
      configs = {
        params = {
          # Expose argocd-server on a ClusterIP (we'll port-forward or add
          # ingress later). No LB spent until there's a reason.
          "server.insecure" = true
        }
      }
      controller = {
        resources = {
          requests = { cpu = "100m", memory = "256Mi" }
          limits   = { cpu = "500m", memory = "512Mi" }
        }
      }
      server = {
        resources = {
          requests = { cpu = "50m", memory = "128Mi" }
          limits   = { cpu = "200m", memory = "256Mi" }
        }
        service = {
          type = "ClusterIP"
        }
      }
      repoServer = {
        resources = {
          requests = { cpu = "50m", memory = "128Mi" }
          limits   = { cpu = "200m", memory = "256Mi" }
        }
      }
    })
  ]

  timeout = 600
}
