# Copy most variables from the original module, but remove VNET-related ones
variable "name" {
  type = string
}

variable "container_app_environment_id" {
  type        = string
  description = "The ID of an existing Container App Environment"
}

variable "resource_group_name" {
  type        = string
  description = "The name of the resource group"
}

variable "image" {
  type = string
}

variable "sha" {
  type = string
}

variable "max_replicas" {
  type        = number
  default     = 1
  description = "Maximum number of replicas"
}

variable "min_replicas" {
  type        = number
  default     = 1
  description = "Minimum number of replicas"
}

variable "cpu" {
  type        = number
  default     = 0.25
  description = "CPU allocation for the container"
}

variable "memory" {
  type        = string
  default     = "0.5Gi"
  description = "Memory allocation for the container"
}

variable "persistent_volumes" {
  type = list(object({
    name         = string
    storage_type = string
    storage_name = optional(string)
  }))
  default     = []
  description = "List of persistent volumes to mount"
}

variable "ingress" {
  type = object({
    allow_insecure_connections = optional(bool, false)
    external_enabled           = optional(bool, true)
    target_port                = number
    transport                  = optional(string, "tcp")
    traffic_weight = optional(list(object({
      percentage      = number
      latest_revision = optional(bool, true)
      revision_suffix = optional(string)
    })))
  })
  default     = null
  description = "Ingress configuration for external access"
}

variable "files" {
  type        = map(string)
  default     = {}
  description = "Files will be mounted to /shared"
}

variable "env" {
  type        = map(string)
  default     = {}
  description = <<EOF
The environment variables for the container. Secrets can be set by prefacing the
value with `secret://`, followed by the contents of the secret env var.

This is done so these values are properly passed as secrets to the container.
Functionally it makes no difference. The only purpose is for Terraform to
recognize them as sensitive values and to store them as secrets in Azure.
EOF
}
