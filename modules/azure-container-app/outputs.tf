output "fqdn" {
  description = "The FQDN of the container app"
  value       = azurerm_container_app.app.latest_revision_fqdn
}

output "name" {
  description = "The name of the container app"
  value       = azurerm_container_app.app.name
}

output "principal_id" {
  description = "The principal ID of the system-assigned managed identity"
  value       = var.enable_system_identity ? azurerm_container_app.app.identity[0].principal_id : null
}
