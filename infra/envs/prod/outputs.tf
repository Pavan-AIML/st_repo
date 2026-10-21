output "resource_group" {
  description = "Resource group that holds everything in this env."
  value       = azurerm_resource_group.main.name
}

output "aks_cluster_name" {
  description = "AKS cluster name. Use with `az aks get-credentials`."
  value       = module.aks.cluster_name
}

output "aks_node_resource_group" {
  description = "The MC_* resource group AKS auto-creates for nodes, LBs, disks."
  value       = module.aks.node_resource_group
}

output "aks_oidc_issuer_url" {
  description = "AKS OIDC issuer URL."
  value       = module.aks.oidc_issuer_url
}

output "acr_login_server" {
  description = "ACR login server, e.g. crshopliteprod.azurecr.io. Prefix for image names."
  value       = module.registry.login_server
}

output "postgres_server_fqdn" {
  description = "Private FQDN of the Postgres server. Resolvable only from inside the VNet."
  value       = module.database.postgres_server_fqdn
}

output "redis_hostname" {
  description = "Redis hostname (public endpoint, TLS-only)."
  value       = module.database.redis_hostname
}

output "workload_identity_client_ids" {
  description = "Map of workload-name -> Entra client ID. Annotate ServiceAccounts with these."
  value       = module.identity.workload_identity_client_ids
}
