output "workload_identity_client_ids" {
  description = "Map of workload-name -> Entra client ID. Annotate the ServiceAccount with azure.workload.identity/client-id = <this value>."
  value       = { for k, v in azurerm_user_assigned_identity.workload : k => v.client_id }
}

output "workload_identity_principal_ids" {
  description = "Map of workload-name -> Entra principal (object) ID. Used when assigning Azure roles (e.g. Key Vault Secrets User) to the identity."
  value       = { for k, v in azurerm_user_assigned_identity.workload : k => v.principal_id }
}

output "workload_identity_ids" {
  description = "Map of workload-name -> full Azure Resource ID of the UAMI."
  value       = { for k, v in azurerm_user_assigned_identity.workload : k => v.id }
}
