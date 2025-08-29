include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "azure" {
  path = find_in_parent_folders("root.provider.azure.hcl")
}

locals {
  root    = include.root.locals
  secrets = local.root.secrets
}

terraform {
  source = "${local.root.root}/modules/azure-container-app-simple"
}

dependency "shared_env" {
  config_path = "../../shared-aca-env"
}

dependencies {
  paths = [
    "../../shared-aca-env",
    "../../../images/mc/player-monitor",
    "../../../images/mc/backup-manager",
  ]
}

inputs = {
  name                         = "minecraft-java"
  resource_group_name          = dependency.shared_env.outputs.resource_group_name
  container_app_environment_id = dependency.shared_env.outputs.container_app_environment_id
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
