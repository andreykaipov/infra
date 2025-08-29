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

  dynamic "secret" {
    for_each = { for k, v in var.env : k => substr(v, length("secret://"), -1) if startswith(v, "secret://") }
    content {
      name  = replace(lower(secret.key), "/[^a-z0-9-.]/", "-")
      value = secret.value
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

    container {
      name   = var.name
      image  = "${var.image}${var.sha == "" ? ":latest" : "@${var.sha}"}"
      cpu    = var.cpu
      memory = var.memory

      dynamic "env" {
        for_each = var.env
        content {
          name        = env.key
          secret_name = startswith(env.value, "secret://") ? replace(lower(env.key), "/[^a-z0-9-.]/", "-") : null
          value       = startswith(env.value, "secret://") ? null : env.value
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
