output "image_name" {
  description = "Full name of the built Docker image"
  value       = docker_image.image.name
}

output "image_id" {
  description = "ID of the built Docker image"
  value       = docker_image.image.image_id
}

output "image_digest" {
  description = "Digest of the built Docker image"
  value       = docker_image.image.repo_digest
}

output "pushed_image_name" {
  description = "Name of the pushed image (null if not pushed)"
  value       = local.pushed_image
}

output "image_details" {
  description = "All image details"
  value = {
    name     = docker_image.image.name
    id       = docker_image.image.image_id
    digest   = docker_image.image.repo_digest
    pushed   = var.push_to_registry
    registry = var.registry_url
    tag      = var.image_tag
  }
}
