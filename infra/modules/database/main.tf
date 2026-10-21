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

# ---------------------------------------------------------------------------
# Postgres admin password.
#
# Generated per env, held in Terraform state (which lives in a locked Azure
# storage account, not in Git). In Phase 5 we copy this into Key Vault and
# pods consume it from there via External Secrets Operator.
# ---------------------------------------------------------------------------
resource "random_password" "postgres_admin" {
  length           = 32
  special          = true
  override_special = "!@#$%^&*()-_=+"
}

# ---------------------------------------------------------------------------
# Azure Database for PostgreSQL — Flexible Server.
#
# VNet-integrated (not public). The server lives inside the delegated DB
# subnet from the networking module and resolves via the private DNS zone,
# so pods reach it over the private network only.
# ---------------------------------------------------------------------------
resource "azurerm_postgresql_flexible_server" "this" {
  name                = "pg-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  version             = var.postgres_version

  administrator_login    = var.postgres_admin_username
  administrator_password = random_password.postgres_admin.result

  sku_name   = var.postgres_sku_name
  storage_mb = var.postgres_storage_mb

  # VNet integration — DB gets a private IP inside the delegated subnet.
  delegated_subnet_id = var.db_subnet_id
  private_dns_zone_id = var.postgres_private_dns_zone_id

  # Backups: 7 days PITR is the Flexible Server default; explicit here for clarity.
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

  # Single-zone for cost. prod could flip to zone-redundant HA later.
  zone = "1"

  tags = var.tags

  lifecycle {
    ignore_changes = [zone, high_availability[0].standby_availability_zone]
  }
}

# ---------------------------------------------------------------------------
# Application database inside the server.
# ---------------------------------------------------------------------------
resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = var.postgres_database_name
  server_id = azurerm_postgresql_flexible_server.this.id
  collation = "en_US.utf8"
  charset   = "UTF8"
}

# ---------------------------------------------------------------------------
# Azure Cache for Redis — Basic C0.
#
# Basic SKU does not support private endpoints or VNet injection (that's
# Premium only, ~20x the cost). For the assessment we use public endpoint
# with TLS-only + access key, store the key in Key Vault in Phase 5, and
# document the tradeoff in docs/adr.
# ---------------------------------------------------------------------------
resource "azurerm_redis_cache" "this" {
  name                 = "redis-${var.name}"
  location             = var.location
  resource_group_name  = var.resource_group_name
  capacity             = var.redis_capacity
  family               = "C"
  sku_name             = var.redis_sku_name
  non_ssl_port_enabled = false
  minimum_tls_version  = "1.2"
  tags                 = var.tags

  redis_configuration {}
}
