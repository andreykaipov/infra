output "fqdn" {
  description = "The FQDN of the container app"
  value       = azurerm_container_app.app.latest_revision_fqdn
}

output "name" {
  description = "The name of the container app"
  value       = azurerm_container_app.app.name
}
