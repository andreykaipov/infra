terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

resource "azurerm_container_app_environment" "env" {
  name                     = var.name
  location                 = var.location
  resource_group_name      = var.resource_group_name
  infrastructure_subnet_id = var.subnet_id

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }

  workload_profile {
    name                  = "Dedicated-D4"
    workload_profile_type = "D4"
    minimum_count         = 0
    maximum_count         = 1
  }
}

# Configure storage for the environment
resource "azurerm_container_app_environment_storage" "storage" {
  count                        = length(var.storage_shares)
  name                         = var.storage_shares[count.index].name
  container_app_environment_id = azurerm_container_app_environment.env.id
  account_name                 = var.storage_shares[count.index].account_name
  access_key                   = var.storage_shares[count.index].account_key
  share_name                   = var.storage_shares[count.index].share_name
  access_mode                  = var.storage_shares[count.index].access_mode
}
