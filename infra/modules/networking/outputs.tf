output "vnet_id" {
  description = "ID of the VNet."
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "Name of the VNet."
  value       = azurerm_virtual_network.this.name
}

output "aks_subnet_id" {
  description = "AKS subnet ID. Passed to the aks module."
  value       = azurerm_subnet.aks.id
}

output "services_subnet_id" {
  description = "Services subnet ID. Used for private endpoints."
  value       = azurerm_subnet.services.id
}

output "db_subnet_ids" {
  description = "Map of env-name -> DB subnet ID. Passed to each env's database module."
  value       = { for k, v in azurerm_subnet.db : k => v.id }
}

output "postgres_private_dns_zone_id" {
  description = "Private DNS zone ID. Passed to the database module."
  value       = azurerm_private_dns_zone.postgres.id
}

output "postgres_private_dns_zone_name" {
  description = "FQDN of the private DNS zone."
  value       = azurerm_private_dns_zone.postgres.name
}
