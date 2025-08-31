variable "name_prefix" {
  description = "The prefix for the storage account name (random suffix will be added for uniqueness)"
  type        = string

  validation {
    condition     = length(var.name_prefix) <= 16
    error_message = "The name_prefix must be 16 characters or less to allow for an 8-character random suffix (24 char limit)."
  }

  validation {
    condition     = can(regex("^[a-z0-9]+$", lower(var.name_prefix)))
    error_message = "The name_prefix must contain only lowercase letters and numbers."
  }
}

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "location" {
  description = "The Azure region"
  type        = string
}

variable "account_tier" {
  description = "Storage account tier"
  type        = string
  default     = "Standard"
}

variable "account_replication_type" {
  description = "Storage account replication type"
  type        = string
  default     = "LRS"
}

variable "tags" {
  description = "A map of tags to assign to the resource"
  type        = map(string)
  default     = {}
}

variable "queues" {
  description = "List of storage queues to create"
  type = list(object({
    name = string
  }))
  default = []
}

variable "file_shares" {
  description = "List of file shares to create"
  type = list(object({
    name  = string
    quota = number
  }))
  default = []
}
