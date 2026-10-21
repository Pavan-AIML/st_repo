variable "name" {
  description = "Short env name used in resource names, e.g. shoplite-staging."
  type        = string
}

variable "location" {
  description = "Azure region, e.g. germanywestcentral."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that will hold the VNet, subnets and DNS zones."
  type        = string
}

variable "vnet_cidr" {
  description = "CIDR for the VNet. One /16 per env, non-overlapping across envs."
  type        = string
  default     = "10.40.0.0/16"
}

variable "aks_subnet_cidr" {
  description = "CIDR for the AKS node subnet. /20 gives ~4k IPs for nodes + pods."
  type        = string
  default     = "10.40.0.0/20"
}

variable "db_subnet_cidr" {
  description = "CIDR for the delegated Postgres Flexible Server subnet."
  type        = string
  default     = "10.40.16.0/24"
}

variable "services_subnet_cidr" {
  description = "CIDR for private endpoints (Redis, Key Vault) and other shared services."
  type        = string
  default     = "10.40.17.0/24"
}

variable "tags" {
  description = "Required tags applied to every resource: owner, task, env."
  type        = map(string)
  default     = {}
}
