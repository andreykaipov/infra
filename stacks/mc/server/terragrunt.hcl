include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "azure" {
  path = "${get_repo_root()}/providers/azure.hcl"
}

terraform {
  source = "${get_repo_root()}/modules/azure-container-app"
}

locals {
  secrets = include.root.locals.secrets
}

dependency "rg" {
  config_path = "../../shared/azure-infra/rg"
  mock_outputs = {
    name = "mock-rg"
  }
}

dependency "env" {
  config_path = "../../shared/azure-infra/container-app-env"
  mock_outputs = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.App/managedEnvironments/mock-env"
  }
}

inputs = {
  name                         = "minecraft-java"
  resource_group_name          = dependency.rg.outputs.name
  container_app_environment_id = dependency.env.outputs.id
  image                        = "itzg/minecraft-server"
  sha                          = ""
  cpu                          = 1.0
  memory                       = "2Gi"
  max_replicas                 = 1
  min_replicas                 = 1

  ingress = {
    external_enabled = true
    target_port      = 25565
    transport        = "tcp"
    traffic_weight = [{
      percentage = 100
    }]
  }

  env = {
    EULA          = "TRUE"
    TYPE          = "PAPER"
    VERSION       = "1.21.8"
    MEMORY        = "2G"
    ENABLE_RCON   = "true"
    RCON_PASSWORD = "secret://${local.secrets.minecraft.rcon_password}"
    RCON_PORT     = "25575"
    SERVER_PORT   = "25565"
    DIFFICULTY    = "normal"
    MODE          = "survival"
    MOTD          = "Minecraft Java Server"
    MAX_PLAYERS   = "20"
    ONLINE_MODE   = "true"
    PVP           = "true"
    LEVEL_NAME    = "world"
    SEED          = ""
  }

  files = {}
}
