variable "name" {
  description = "Short env name, e.g. shoplite-staging. Used in registry name after stripping hyphens."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "RG that holds the registry."
  type        = string
}

variable "sku" {
  description = "ACR SKU. Basic is cheapest (~€0.14/day). Premium adds private endpoints and geo-replication."
  type        = string
  default     = "Basic"
}

variable "kubelet_identity_object_id" {
  description = "Object ID of the AKS kubelet identity. Granted AcrPull on this registry."
  type        = string
}

variable "github_actions_principal_id" {
  description = "Optional. Entra principal ID for GitHub Actions OIDC — granted AcrPush. Null for Task 1."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to the registry."
  type        = map(string)
  default     = {}
}
