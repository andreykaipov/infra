include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "azure" {
  path = "${get_repo_root()}/providers/azure.hcl"
}

terraform {
  source = "${get_repo_root()}/modules/azure-network"
}

dependency "rg" {
  config_path = "../rg"
  mock_outputs = {
    name = "mock-rg"
  }
}

locals {
  root = include.root.locals
}

inputs = {
  vnet_name             = local.root.project
  subnet_name           = local.root.project
  nsg_name              = local.root.project
  location              = "eastus"
  resource_group_name   = dependency.rg.outputs.name
  address_space         = ["10.0.0.0/16"]
  subnet_address_prefix = "10.0.0.0/22" # /22 for shared container apps (1024 IPs)

  additional_ports = {
    minecraft      = { port = 25565 }
    minecraft_rcon = { port = 25575 }
  }
}
