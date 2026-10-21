variable "name" {
  description = "Short platform name, e.g. shoplite. Used in resource names."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "RG that holds the VNet, subnets and DNS zones."
  type        = string
}

variable "vnet_cidr" {
  description = "CIDR for the shared VNet. All subnets must fit inside."
  type        = string
  default     = "10.40.0.0/16"
}

variable "aks_subnet_cidr" {
  description = "CIDR for the AKS node subnet. /20 = ~4k IPs for nodes + pods."
  type        = string
  default     = "10.40.0.0/20"
}

variable "services_subnet_cidr" {
  description = "CIDR for private endpoints (Redis, Key Vault) and shared services."
  type        = string
  default     = "10.40.17.0/24"
}

variable "db_subnet_cidrs" {
  description = <<-EOT
    Map of env-name -> CIDR for per-env delegated Postgres subnets.
    Example: { staging = "10.40.18.0/24", prod = "10.40.19.0/24" }
  EOT
  type        = map(string)
  default = {
    staging = "10.40.18.0/24"
    prod    = "10.40.19.0/24"
  }
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
