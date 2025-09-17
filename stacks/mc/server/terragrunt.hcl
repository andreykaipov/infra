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
        EULA              = "TRUE"
        TYPE              = "FABRIC"
        VERSION           = "1.21.8"
        MODRINTH_PROJECTS = <<EOF
fabric-api
lithium
ferrite-core

chunky
vanilla-refresh
inventory-sorting
fallingtree

terralith
towns-and-towers
refined-advancements
scorched
spellbound-weapons
true-ending

cristel-lib
lithostitched
cloth-config
collective

villager-names-serilum
piglin-names
realistic-bees
pumpkillagers-quest
mineral-chance
double-doors
bareback-horse-riding
no-hostiles-around-campfire
healing-campfire
milk-all-the-mobs
paper-books
villager-death-messages
infinite-trading
grass-seeds
crying-portals
starter-kit
inventory-totem
quick-right-click
EOF
        # terralith
        # chunky

        OPS         = <<EOF
IntimateMuffin
EOF
        MEMORY      = "7G"
        ENABLE_RCON = "true"
        RCON_PORT   = "25575"
        RCON_HOST   = "0.0.0.0"

        #         # Auto-download mods by listing URLs in MODS (comma or newline separated)
        #         # replace the example URLs with actual versions you want
        #         MODS = <<EOF
        # http:s//github.com/CaffeineMC/lithium-fabric/releases/download/vX.X/lithium-fabric-X.X.jar
        # https://github.com/jellysquid3/phosphor-fabric/releases/download/vY.Y/phosphor-fabric-Y.Y.jar
        # EOF
        REMOVE_OLD_MODS = "TRUE"
        SERVER_PORT     = "25566"
        DIFFICULTY      = "hard"
        MODE            = "survival"
        MOTD            = "Minecraft Java Server"
        MAX_PLAYERS     = "20"
        ONLINE_MODE     = "true"
        PVP             = "true"
        LEVEL_NAME      = "world"
        SEED            = ""
        UID             = "0"
        GID             = "0"
        RCON_PASSWORD   = local.secrets.minecraft.rcon_password
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
