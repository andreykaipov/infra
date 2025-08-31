# Generate a random suffix for global uniqueness
resource "random_string" "suffix" {
  length  = 8
  lower   = true
  upper   = false
  numeric = true
  special = false
}

locals {
  # Ensure the full name doesn't exceed 24 characters and is lowercase
  max_prefix_length = 24 - 8 # Reserve 8 chars for suffix
  name_prefix_clean = lower(substr(var.name_prefix, 0, local.max_prefix_length))
  storage_name      = "${local.name_prefix_clean}${random_string.suffix.result}"
}

resource "azurerm_storage_account" "account" {
  name                     = local.storage_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = var.account_tier
  account_replication_type = var.account_replication_type

  blob_properties {
    versioning_enabled = true
  }

  tags = var.tags
}

# Create storage queues
resource "azurerm_storage_queue" "queue" {
  for_each             = { for q in var.queues : q.name => q }
  name                 = each.value.name
  storage_account_name = azurerm_storage_account.account.name
}

# Create file shares
resource "azurerm_storage_share" "share" {
  for_each           = { for s in var.file_shares : s.name => s }
  name               = each.value.name
  storage_account_id = azurerm_storage_account.account.id
  quota              = each.value.quota
}
