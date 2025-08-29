output "name" {
  description = "Full name of the built Docker image"
  value       = docker_image.image.name
}

output "id" {
  description = "ID of the built Docker image"
  value       = docker_image.image.image_id
}

output "digest" {
  description = "Digest of the built Docker image"
  value       = docker_image.image.repo_digest
}

output "pushed_name" {
  description = "Name of the pushed image (null if not pushed)"
  value       = local.pushed_image
}

output "details" {
  description = "All image details"
  value = {
    name     = docker_image.image.name
    id       = docker_image.image.image_id
    digest   = docker_image.image.repo_digest
    pushed   = var.push_to_registry
    registry = var.registry_url
    tag      = var.tag
  }
}
