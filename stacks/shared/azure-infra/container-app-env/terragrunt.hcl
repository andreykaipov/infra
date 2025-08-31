include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "azure" {
  path = "${get_repo_root()}/providers/azure.hcl"
}

terraform {
  source = "${get_repo_root()}/modules/azure-container-app-environment"
}

dependency "rg" {
  config_path = "../rg"
  mock_outputs = {
    name = "mock-rg"
  }
}

dependency "network" {
  config_path = "../network"
  mock_outputs = {
    subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet/subnets/mock-subnet"
  }
}

dependency "storage" {
  config_path = "../storage"
  mock_outputs = {
    name               = "mock-storage"
    primary_access_key = "mock-key"
  }
}

locals {
  root = include.root.locals
}

inputs = {
  name                = local.root.project
  location            = "eastus"
  resource_group_name = dependency.rg.outputs.name
  subnet_id           = dependency.network.outputs.subnet_id

  storage_shares = [
    {
      name         = "minecraft-storage"
      account_name = dependency.storage.outputs.name
      account_key  = dependency.storage.outputs.primary_access_key
      share_name   = "minecraft-data"
      access_mode  = "ReadWrite"
    }
  ]
}
