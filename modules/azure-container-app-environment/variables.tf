variable "name" {
  type        = string
  description = "Name for the Container App Environment and related resources"
}

variable "location" {
  type        = string
  description = "Azure region for the resources"
}

variable "create_vnet" {
  type        = bool
  default     = false
  description = "Whether to create a custom VNET for external TCP access"
}

variable "vnet_address_space" {
  type        = list(string)
  default     = ["10.0.0.0/16"]
  description = "Address space for the virtual network"
}

variable "subnet_address_prefix" {
  type        = string
  default     = "10.0.0.0/23"
  description = "Address prefix for the container apps subnet (minimum /23 required)"
}

variable "allowed_inbound_ports" {
  type = list(object({
    name     = string
    port     = string
    protocol = string
  }))
  default     = []
  description = "List of additional inbound ports to allow"
}
