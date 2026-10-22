output "postgres_server_fqdn" {
  description = "Private FQDN of the Postgres server."
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

# ---------------------------------------------------------------------------
# Redis — see ADR-003. Moved in-cluster via Helm chart (installed by GitOps).
# Pods reach it at redis-master.redis.svc.cluster.local:6379.
# No Terraform-managed Redis outputs anymore.
# ---------------------------------------------------------------------------
