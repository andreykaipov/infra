terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

resource "azurerm_container_app" "app" {
  name                         = var.name
  container_app_environment_id = var.container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  workload_profile_name        = var.workload_profile_name

  dynamic "identity" {
    for_each = var.enable_system_identity ? [1] : []
    content {
      type = "SystemAssigned"
    }
  }

  dynamic "ingress" {
    for_each = var.ingress != null ? [var.ingress] : []
    content {
      allow_insecure_connections = ingress.value.allow_insecure_connections
      external_enabled           = ingress.value.external_enabled
      target_port                = ingress.value.target_port
      transport                  = ingress.value.transport

      dynamic "traffic_weight" {
        for_each = ingress.value.traffic_weight != null ? ingress.value.traffic_weight : []
        content {
          percentage      = traffic_weight.value.percentage
          latest_revision = traffic_weight.value.latest_revision
          revision_suffix = traffic_weight.value.revision_suffix
        }
      }
    }
  }

  template {
    max_replicas = var.max_replicas
    min_replicas = var.min_replicas

    volume {
      name         = "shared"
      storage_type = "EmptyDir"
    }

    dynamic "volume" {
      for_each = var.persistent_volumes
      content {
        name         = volume.value.name
        storage_type = volume.value.storage_type
        storage_name = volume.value.storage_name
      }
    }

    dynamic "init_container" {
      for_each = length(var.files) > 0 ? [1] : []
      content {
        name   = "copy-files"
        image  = "alpine:latest"
        cpu    = 0.25
        memory = "0.5Gi"
        command = [
          "/bin/sh",
          "-c",
          join("\n", [
            for k, v in var.files :
            "cat >/shared/${k} <<'LOL'\n${v}\nLOL\n"
          ])
        ]

        volume_mounts {
          name = "shared"
          path = "/shared"
        }
      }
    }

    # Containers
    dynamic "container" {
      for_each = var.containers
      content {
        name   = container.value.name
        image  = "${container.value.image}${container.value.sha == "" ? ":latest" : "@${container.value.sha}"}"
        cpu    = container.value.cpu
        memory = container.value.memory

        dynamic "env" {
          for_each = container.value.env
          content {
            name  = env.key
            value = env.value
          }
        }

        volume_mounts {
          name = "shared"
          path = "/shared"
        }

        dynamic "volume_mounts" {
          for_each = var.persistent_volumes
          content {
            name = volume_mounts.value.name
            path = "/data"
          }
        }
      }
    }
  }
}

# Role assignment to allow the container app to manage itself for scaling
resource "azurerm_role_assignment" "container_app_contributor" {
  count = var.enable_system_identity ? 1 : 0
  # assign at the resource group level so the managed identity can perform
  # Microsoft.App/containerApps/* actions like start/stop against the app
  # (resource-level RBAC can sometimes be insufficient depending on provider
  # action definitions and timing during resource creation)
  scope                = data.azurerm_resource_group.rg.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_container_app.app.identity[0].principal_id
}

data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}
