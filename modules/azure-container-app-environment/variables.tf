variable "name" {
  type        = string
  description = "Name for the Container App Environment"
}

variable "location" {
  type        = string
  description = "Azure region for the resources"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group to create resources in"
}

variable "subnet_id" {
  type        = string
  default     = null
  description = "ID of the subnet to use for the Container App Environment (optional)"
}

variable "storage_shares" {
  type = list(object({
    name         = string
    account_name = string
    account_key  = string
    share_name   = string
    access_mode  = optional(string, "ReadWrite")
  }))
  default     = []
  description = "List of Azure File storage shares to mount"
}
