output "vnet_id" {
  description = "ID of the VNet. Consumed by the DNS zone link and future peerings."
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

output "db_subnet_id" {
  description = "Delegated Postgres subnet ID. Passed to the database module."
  value       = azurerm_subnet.db.id
}

output "services_subnet_id" {
  description = "Services subnet ID. Used for private endpoints."
  value       = azurerm_subnet.services.id
}

output "postgres_private_dns_zone_id" {
  description = "Private DNS zone ID. Passed to the database module to attach the server."
  value       = azurerm_private_dns_zone.postgres.id
}

output "postgres_private_dns_zone_name" {
  description = "FQDN of the private DNS zone, e.g. shoplite-staging.postgres.database.azure.com."
  value       = azurerm_private_dns_zone.postgres.name
}
