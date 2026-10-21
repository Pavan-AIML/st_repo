output "registry_id" {
  description = "ACR resource ID."
  value       = azurerm_container_registry.this.id
}

output "login_server" {
  description = "Fully-qualified login server, e.g. crshoplitestaging.azurecr.io. Used as image prefix in K8s manifests."
  value       = azurerm_container_registry.this.login_server
}

output "name" {
  description = "ACR registry name (without .azurecr.io). Used with az acr login --name."
  value       = azurerm_container_registry.this.name
}
