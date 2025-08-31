include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "azure" {
  path = "${get_repo_root()}/providers/azure.hcl"
}

dependency "rg" {
  config_path = "../rg"
}

locals {
  root = include.root.locals
}

terraform {
  source = "${local.root.root}/modules/azure-storage-account"
}

inputs = {
  name_prefix              = local.root.project
  resource_group_name      = dependency.rg.outputs.name
  location                 = dependency.rg.outputs.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  queues = [
    {
      name = "player-activity"
    }
  ]

  file_shares = [
    {
      name  = "minecraft-data"
      quota = 10
    }
  ]

  tags = {
    environment = "production"
    project     = local.root.project
  }
}
