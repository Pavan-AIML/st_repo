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
# VNet-integrated (not public). AzureRM 4.x requires explicit
# public_network_access_enabled = false when the DB is VNet-attached.
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
  delegated_subnet_id           = var.db_subnet_id
  private_dns_zone_id           = var.postgres_private_dns_zone_id
  public_network_access_enabled = false

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

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
# Redis — ADR-003: Microsoft retired Azure Cache for Redis in October 2026;
# new creates are rejected. The replacement (Azure Managed Redis / Redis
# Enterprise) starts at ~€200/mo, blowing the assessment budget. We moved
# Redis in-cluster via the Bitnami Redis Helm chart installed by GitOps.
#
# This module therefore creates NO Redis resource. The worker reaches Redis
# at redis-master.redis.svc.cluster.local:6379 inside the cluster.
# ---------------------------------------------------------------------------
