terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0, < 4.0"
    }
  }
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.name}-rg"
  location = var.location
  tags = {
    name = var.name
  }
}

resource "azurerm_container_app_environment" "env" {
  name                = "${var.name}-env"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_container_app" "app" {
  name                         = var.name
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  dynamic "secret" {
    for_each = { for k, v in var.env : k => substr(v, length("secret://"), -1) if startswith(v, "secret://") }
    content {
      name  = replace(lower(secret.key), "/[^a-z0-9-.]/", "-")
      value = secret.value
    }
  }

  template {
    max_replicas = 1
    min_replicas = 1

    volume {
      name         = "shared"
      storage_type = "EmptyDir"
    }

    init_container {
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

    container {
      name   = var.name
      image  = "${var.image}${var.sha == "" ? ":latest" : "@${var.sha}"}"
      cpu    = 0.25
      memory = "0.5Gi"
      # command = ["sh", "-c", "tail -f /dev/null"]
      args = ["discord"]

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
    }
  }
}
