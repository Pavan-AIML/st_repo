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
# Shared Virtual Network — hosts the AKS cluster and every env's DB subnet.
# One /16 for the whole platform; subnets carved out for each role.
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_cidr]
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# AKS subnet — nodes and pods get IPs from this range.
# ---------------------------------------------------------------------------
resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.aks_subnet_cidr]
}

# ---------------------------------------------------------------------------
# Services subnet — host for private endpoints (Redis, Key Vault) and
# internal ILBs. Shared across envs.
# ---------------------------------------------------------------------------
resource "azurerm_subnet" "services" {
  name                              = "snet-services"
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.this.name
  address_prefixes                  = [var.services_subnet_cidr]
  private_endpoint_network_policies = "Disabled"
}

# ---------------------------------------------------------------------------
# Per-env database subnets — one delegated subnet per Postgres Flexible
# Server. Each env gets its own CIDR so DBs can be torn down independently.
#
# Keyed on env name (e.g. "staging", "prod") so staging and prod can reference
# their specific subnet by name from the output map.
# ---------------------------------------------------------------------------
resource "azurerm_subnet" "db" {
  for_each = var.db_subnet_cidrs

  name                              = "snet-db-${each.key}"
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.this.name
  address_prefixes                  = [each.value]
  private_endpoint_network_policies = "Disabled"

  delegation {
    name = "fs"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# ---------------------------------------------------------------------------
# Private DNS zone for Postgres. Both env Postgres servers register here.
# ---------------------------------------------------------------------------
resource "azurerm_private_dns_zone" "postgres" {
  name                = "${var.name}.postgres.database.azure.com"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "pdz-link-postgres"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.this.id
  registration_enabled  = false
  tags                  = var.tags
}
