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
# Virtual Network — the private IP space everything else lives inside.
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
# DB subnet — delegated to Postgres Flexible Server so the DB lives inside
# the VNet (no public endpoint). Azure requires a dedicated subnet + the
# "fs" delegation for this to work.
# ---------------------------------------------------------------------------
resource "azurerm_subnet" "db" {
  name                              = "snet-db"
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.this.name
  address_prefixes                  = [var.db_subnet_cidr]
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
# Services subnet — host for private endpoints (Redis, Key Vault) and
# ingress internal load balancer if we ever need one.
# ---------------------------------------------------------------------------
resource "azurerm_subnet" "services" {
  name                              = "snet-services"
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.this.name
  address_prefixes                  = [var.services_subnet_cidr]
  private_endpoint_network_policies = "Disabled"
}

# ---------------------------------------------------------------------------
# Private DNS zone for Postgres Flexible Server. Pods resolve the DB's
# <name>.postgres.database.azure.com hostname to a private IP via this zone.
# The database module will attach the server to this zone.
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
