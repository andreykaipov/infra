include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "azure" {
  path = find_in_parent_folders("root.provider.azure.hcl")
}

locals {
  root = include.root.locals
}

terraform {
  source = "${local.root.root}/modules/azure-container-app-environment"
}

inputs = {
  name        = local.root.project
  location    = "eastus"
  create_vnet = true

  # Allow common application ports - can be extended as needed
  allowed_inbound_ports = [
    {
      name     = "Minecraft"
      port     = "25565"
      protocol = "Tcp"
    },
    {
      name     = "MinecraftRCON"
      port     = "25575"
      protocol = "Tcp"
    }
  ]
}
