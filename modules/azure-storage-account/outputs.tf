output "name" {
  description = "The name of the storage account"
  value       = azurerm_storage_account.account.name
}

output "primary_connection_string" {
  description = "The primary connection string for the storage account"
  value       = azurerm_storage_account.account.primary_connection_string
  sensitive   = true
}

output "primary_access_key" {
  description = "The primary access key for the storage account"
  value       = azurerm_storage_account.account.primary_access_key
  sensitive   = true
}

output "queue_endpoint" {
  description = "The endpoint URL for queue operations"
  value       = azurerm_storage_account.account.primary_queue_endpoint
}

output "queues" {
  description = "Map of created storage queues"
  value       = azurerm_storage_queue.queue
}

output "file_shares" {
  description = "Map of created file shares"
  value       = azurerm_storage_share.share
}
