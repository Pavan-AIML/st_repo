output "postgres_server_fqdn" {
  description = "Private FQDN of the Postgres server, e.g. pg-shoplite-staging.<zone>.postgres.database.azure.com."
  value       = azurerm_postgresql_flexible_server.this.fqdn
}

output "postgres_database_name" {
  description = "Name of the application database inside the server."
  value       = azurerm_postgresql_flexible_server_database.app.name
}

output "postgres_admin_username" {
  description = "Postgres admin login name."
  value       = azurerm_postgresql_flexible_server.this.administrator_login
}

output "postgres_admin_password" {
  description = "Generated Postgres admin password. Sensitive — only ever printed into Key Vault."
  value       = random_password.postgres_admin.result
  sensitive   = true
}

output "postgres_connection_string" {
  description = "Full SQLAlchemy-style connection string. Sensitive."
  value       = "postgresql+asyncpg://${azurerm_postgresql_flexible_server.this.administrator_login}:${random_password.postgres_admin.result}@${azurerm_postgresql_flexible_server.this.fqdn}:5432/${azurerm_postgresql_flexible_server_database.app.name}"
  sensitive   = true
}

output "redis_hostname" {
  description = "Redis hostname, e.g. redis-shoplite-staging.redis.cache.windows.net."
  value       = azurerm_redis_cache.this.hostname
}

output "redis_ssl_port" {
  description = "Redis TLS port (6380)."
  value       = azurerm_redis_cache.this.ssl_port
}

output "redis_primary_access_key" {
  description = "Redis primary access key. Sensitive — goes into Key Vault."
  value       = azurerm_redis_cache.this.primary_access_key
  sensitive   = true
}

output "redis_connection_string" {
  description = "redis:// URL with password and TLS. Sensitive."
  value       = "rediss://:${azurerm_redis_cache.this.primary_access_key}@${azurerm_redis_cache.this.hostname}:${azurerm_redis_cache.this.ssl_port}"
  sensitive   = true
}
