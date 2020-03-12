variable "location" {
  description = "Region in which resources will be created"
  default     = "eastus"
}

variable "tags" {
  description = "Tags map to use for resources to be deployed"
  type        = "map"

  default = {
    environment = "dev"
  }
}

variable "resource_group_name" {
  description = "Name of the rg where resources will be created"
  default     = "gft-demo-ss-rg1"
}

variable "application_port" {
  description = "Appln port to be exposed to LB"
  default     = 80
}

variable "admin_user" {
  description = "Admin username for servers in VMSS"
  default     = "localadmin"
}

variable "admin_password" {
  description = "Default password for the admin account"
  default     = "Passwd123!"
}