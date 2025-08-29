output "container_app_environment_id" {
  description = "The ID of the Container App Environment"
  value       = azurerm_container_app_environment.env.id
}

output "resource_group_name" {
  description = "The name of the resource group"
  value       = azurerm_resource_group.rg.name
}

output "location" {
  description = "The location of the resources"
  value       = azurerm_resource_group.rg.location
}

output "vnet_id" {
  description = "The ID of the virtual network (if created)"
  value       = var.create_vnet ? azurerm_virtual_network.vnet[0].id : null
}

output "subnet_id" {
  description = "The ID of the container apps subnet (if created)"
  value       = var.create_vnet ? azurerm_subnet.subnet[0].id : null
}
