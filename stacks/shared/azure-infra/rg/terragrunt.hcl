include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "azure" {
  path = "${get_repo_root()}/providers/azure.hcl"
}

terraform {
  source = "${get_repo_root()}/modules/azure-resource-group"
}

locals {
  root = include.root.locals
}

inputs = {
  name     = local.root.project
  location = "eastus"
}
