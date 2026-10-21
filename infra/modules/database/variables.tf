variable "name" {
  description = "Short env name, e.g. shoplite-staging."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "RG that holds the Postgres server and Redis cache."
  type        = string
}

# ---------------------------------------------------------------------------
# Postgres
# ---------------------------------------------------------------------------

variable "db_subnet_id" {
  description = "Delegated subnet ID for Postgres Flexible Server. From networking module."
  type        = string
}

variable "postgres_private_dns_zone_id" {
  description = "Private DNS zone ID the Postgres server attaches to. From networking module."
  type        = string
}

variable "postgres_version" {
  description = "Postgres major version."
  type        = string
  default     = "16"
}

variable "postgres_sku_name" {
  description = "Postgres Flexible Server SKU. B_Standard_B1ms is burstable, cheapest tier."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "postgres_storage_mb" {
  description = "Postgres storage in MB. 32768 = 32 GiB (smallest allowed)."
  type        = number
  default     = 32768
}

variable "postgres_admin_username" {
  description = "Postgres administrator login name."
  type        = string
  default     = "shoplite"
}

variable "postgres_database_name" {
  description = "Application database name created inside the server."
  type        = string
  default     = "shoplite"
}

# ---------------------------------------------------------------------------
# Redis
# ---------------------------------------------------------------------------

variable "redis_sku_name" {
  description = "Redis SKU. Basic has no SLA / no replication / no private endpoint."
  type        = string
  default     = "Basic"
}

variable "redis_capacity" {
  description = "Redis cache size tier. 0 = C0 (250 MB, cheapest)."
  type        = number
  default     = 0
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
