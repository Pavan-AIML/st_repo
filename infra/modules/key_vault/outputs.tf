output "vault_uri" {
  description = "https://<name>.vault.azure.net/ — ESO ClusterSecretStore uses this."
  value       = azurerm_key_vault.this.vault_uri
}

output "vault_name" {
  value = azurerm_key_vault.this.name
}

output "vault_id" {
  value = azurerm_key_vault.this.id
}
