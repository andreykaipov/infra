variable "image_name" {
  description = "Name of the Docker image (e.g., 'andreykaipov/minecraft-player-monitor')"
  type        = string
}

variable "image_tag" {
  description = "Tag for the Docker image"
  type        = string
  default     = "latest"
}

variable "build_context" {
  description = "Path to the build context"
  type        = string
  default     = "."
}

variable "dockerfile_path" {
  description = "Path to the Dockerfile relative to build context"
  type        = string
  default     = "Dockerfile"
}

variable "build_args" {
  description = "Build arguments to pass to Docker build"
  type        = map(string)
  default     = {}
}

variable "labels" {
  description = "Labels to add to the Docker image"
  type        = map(string)
  default     = {}
}

variable "target_stage" {
  description = "Target stage for multi-stage builds"
  type        = string
  default     = null
}

variable "platform" {
  description = "Target platform for the build (e.g., 'linux/amd64')"
  type        = string
  default     = null
}

variable "no_cache" {
  description = "Do not use cache when building the image"
  type        = bool
  default     = false
}
variable "source_files_pattern" {
  description = "Glob pattern for source files that trigger rebuilds"
  type        = string
  default     = "**/*"
}

variable "rebuild_triggers" {
  description = "Custom triggers for rebuilding the image"
  type        = map(string)
  default     = null
}

variable "push_to_registry" {
  description = "Whether to push the image to a registry"
  type        = bool
  default     = true
}

variable "keep_remotely" {
  description = "Keep the image in the registry on a destroy"
  type        = bool
  default     = true
}

variable "registry_url" {
  description = "Docker registry URL (leave null for Docker Hub)"
  type        = string
  default     = null
}

variable "registry_auth" {
  description = "Registry authentication configuration"
  type = object({
    username = string
    password = string
  })
  default   = null
  sensitive = true
}
