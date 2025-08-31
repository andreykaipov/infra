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

variable "workload_profile_name" {
  type        = string
  default     = null
  description = "The name of the workload profile to use. If not specified, uses Consumption profile."
}

variable "enable_system_identity" {
  type        = bool
  default     = false
  description = "Enable system-assigned managed identity for the container app"
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

variable "containers" {
  type = list(object({
    name   = string
    image  = string
    sha    = optional(string, "")
    cpu    = optional(number, 0.25)
    memory = optional(string, "0.5Gi")
    env    = optional(map(string), {})
  }))
  description = "List of containers to run in the pod"
  sensitive   = true
}
