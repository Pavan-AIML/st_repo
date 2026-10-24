# ---------------------------------------------------------------------------
# Outputs consumed by envs/staging and envs/prod via terraform_remote_state.
# ---------------------------------------------------------------------------

output "resource_group" {
  value = azurerm_resource_group.shared.name
}

output "aks_cluster_name" {
  value = module.aks.cluster_name
}

output "aks_oidc_issuer_url" {
  value = module.aks.oidc_issuer_url
}

output "aks_node_resource_group" {
  value = module.aks.node_resource_group
}

output "acr_login_server" {
  value = module.registry.login_server
}

output "db_subnet_ids" {
  description = "Map of env-name -> DB subnet ID. Staging/prod read their own by key."
  value       = module.networking.db_subnet_ids
}

output "postgres_private_dns_zone_id" {
  value = module.networking.postgres_private_dns_zone_id
}

# GitHub Actions identity — paste client_id into GH repo variable AZURE_CLIENT_ID.
output "github_actions_client_id" {
  description = "Entra client ID of the GHA UAMI. Set as GitHub repo variable AZURE_CLIENT_ID."
  value       = azurerm_user_assigned_identity.github_actions.client_id
}

output "github_actions_principal_id" {
  description = "Entra principal (object) ID of the GHA UAMI."
  value       = azurerm_user_assigned_identity.github_actions.principal_id
}
