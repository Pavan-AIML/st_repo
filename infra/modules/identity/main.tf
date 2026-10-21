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
# User-assigned managed identity per workload.
#
# One Azure identity per Kubernetes ServiceAccount that needs to call
# Azure APIs. The federated credential (below) binds the identity to the
# ServiceAccount via the AKS OIDC issuer, so pods using that SA get
# short-lived Entra tokens with no password anywhere.
#
# `for_each` keyed on workload name so adding more workloads later is a
# map-entry change, not a copy-paste.
# ---------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "workload" {
  for_each = var.workloads

  name                = "id-wi-${each.key}-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Federated identity credential.
#
# This is the trust policy: "trust the AKS cluster at this OIDC issuer URL,
# accept tokens whose `sub` claim equals system:serviceaccount:<ns>:<sa>,
# with audience api://AzureADTokenExchange."
#
# When a pod with that SA requests an Azure token, the AKS mutating webhook
# projects a short-lived SA token into the pod. The pod exchanges that SA
# token for an Entra token at login.microsoftonline.com. Entra validates
# the signature against this federated credential and issues the Entra
# token. No client secret involved anywhere.
# ---------------------------------------------------------------------------
resource "azurerm_federated_identity_credential" "workload" {
  for_each = var.workloads

  name                = "fed-${each.key}-${var.name}"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.workload[each.key].id

  audience = ["api://AzureADTokenExchange"]
  issuer   = var.oidc_issuer_url
  subject  = "system:serviceaccount:${each.value.namespace}:${each.value.service_account}"
}
