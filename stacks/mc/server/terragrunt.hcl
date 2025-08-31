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
    name     = "mock-rg"
    location = "eastus"
  }
}

dependency "env" {
  config_path = "../../shared/azure-infra/container-app-env"
  mock_outputs = {
    id = "mock-env-id"
  }
}

dependency "storage" {
  config_path = "../../shared/azure-infra/storage"
}

inputs = {
  name                         = "minecraft-java"
  container_app_environment_id = dependency.env.outputs.id
  resource_group_name          = dependency.rg.outputs.name
  workload_profile_name        = "Consumption"
  enable_system_identity       = true

  max_replicas = 1
  min_replicas = 1 // instead, the player-monitor stops the container app if there are no players

  ingress = {
    external_enabled = false # external ingress is through proxy
    target_port      = 25566
    transport        = "tcp"
    traffic_weight = [{
      percentage      = 100
      latest_revision = true
    }]
  }

  containers = [
    {
      name   = "minecraft"
      image  = "itzg/minecraft-server"
      sha    = ""
      cpu    = 2.0
      memory = "4Gi"
      env = {
        EULA          = "TRUE"
        TYPE          = "PAPER"
        VERSION       = "1.21.8"
        MEMORY        = "3G"
        ENABLE_RCON   = "true"
        RCON_PORT     = "25575"
        RCON_HOST     = "0.0.0.0"
        SERVER_PORT   = "25566"
        DIFFICULTY    = "normal"
        MODE          = "survival"
        MOTD          = "Minecraft Java Server"
        MAX_PLAYERS   = "20"
        ONLINE_MODE   = "true"
        PVP           = "true"
        LEVEL_NAME    = "world"
        SEED          = ""
        UID           = "0"
        GID           = "0"
        RCON_PASSWORD = local.secrets.minecraft.rcon_password
      }
    },
    {
      name   = "player-monitor"
      image  = "ghcr.io/andreykaipov/infra/images/mc/player-monitor"
      sha    = ""
      cpu    = 0.25
      memory = "0.5Gi"
      env = {
        MINECRAFT_HOST           = "localhost"
        RCON_PORT                = "25575"
        RCON_PASSWORD            = local.secrets.minecraft.rcon_password
        CHECK_INTERVAL           = "30s"
        INACTIVITY_TIMEOUT       = "5m"
        STOP_METHOD              = "azure"
        AZURE_SUBSCRIPTION_ID    = local.secrets.azure.subscription_id
        AZURE_RESOURCE_GROUP     = dependency.rg.outputs.name
        AZURE_CONTAINER_APP_NAME = "minecraft-java"
      }
    }
  ]

  persistent_volumes = [
    {
      name         = "minecraft-storage"
      storage_type = "AzureFile"
      storage_name = "minecraft-storage"
    }
  ]
}
