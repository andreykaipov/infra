terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# Dynamic provider configuration based on registry auth
provider "docker" {
  dynamic "registry_auth" {
    for_each = var.registry_auth != null ? [var.registry_auth] : []

    content {
      address  = var.registry_url != null ? var.registry_url : "registry-1.docker.io"
      username = registry_auth.value.username
      password = registry_auth.value.password
    }
  }
}
