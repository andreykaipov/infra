# Build the Docker image

locals {
  pushed_image = var.push_to_registry ? docker_registry_image.pushed_image[0].name : null
}

resource "docker_image" "image" {
  name = "${var.image_name}:${var.image_tag}"
  build {
    context    = var.build_context
    dockerfile = var.dockerfile_path
    build_args = var.build_args
    labels     = var.labels
    target     = var.target_stage
    platform   = var.platform
    no_cache   = var.no_cache
  }

  # Rebuild when source files change
  triggers = var.rebuild_triggers != null ? var.rebuild_triggers : {
    dir_sha1 = sha1(join("", [
      for f in fileset(var.build_context, var.source_files_pattern) :
      filesha1("${var.build_context}/${f}")
    ]))
    dockerfile = filesha1("${var.build_context}/${var.dockerfile_path}")
  }
}

# Push to registry if enabled
resource "docker_registry_image" "pushed_image" {
  count = var.push_to_registry ? 1 : 0

  name          = docker_image.image.name
  keep_remotely = var.keep_remotely

  triggers = {
    image_id = docker_image.image.image_id
  }
}
