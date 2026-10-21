output "resource_group" {
  value = azurerm_resource_group.env.name
}

output "postgres_server_fqdn" {
  value = module.database.postgres_server_fqdn
}

output "redis_hostname" {
  value = module.database.redis_hostname
}

output "workload_identity_client_ids" {
  description = "Map of workload-name -> Entra client ID. Annotate ServiceAccounts with these."
  value       = module.identity.workload_identity_client_ids
}
