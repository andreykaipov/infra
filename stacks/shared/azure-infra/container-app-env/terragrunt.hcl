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

locals {
  root = include.root.locals
}

inputs = {
  name                = local.root.project
  location            = "eastus"
  resource_group_name = dependency.rg.outputs.name
  subnet_id           = dependency.network.outputs.subnet_id
}
