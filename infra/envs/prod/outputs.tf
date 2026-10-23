output "resource_group" {
  value = azurerm_resource_group.env.name
}

output "postgres_server_fqdn" {
  value = module.database.postgres_server_fqdn
}

# Redis moved in-cluster — no Azure Redis output (see ADR-003).
# Workers reach it at redis-master.redis.svc.cluster.local:6379.

output "workload_identity_client_ids" {
  description = "Map of workload-name -> Entra client ID. Annotate ServiceAccounts with these."
  value       = module.identity.workload_identity_client_ids
}

output "key_vault_uri" {
  description = "Key Vault URI. Consumed by the ESO ClusterSecretStore in GitOps."
  value       = module.key_vault.vault_uri
}

output "key_vault_name" {
  value = module.key_vault.vault_name
}
