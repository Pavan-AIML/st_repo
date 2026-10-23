variable "name" {
  description = "Short env name, used in the vault name (kv-<name>-<suffix>)."
  type        = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "deployer_object_id" {
  description = "Entra object ID of whoever runs terraform apply. Gets Key Vault Administrator."
  type        = string
}

variable "workload_principal_id" {
  description = "Workload identity principal ID. Gets Key Vault Secrets User (read-only)."
  type        = string
}

variable "secrets" {
  description = "Map of secret-name -> value. Mark as sensitive at the caller."
  type        = map(string)
  sensitive   = true
  default     = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
