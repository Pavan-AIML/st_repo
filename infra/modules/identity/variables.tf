variable "name" {
  description = "Short env name, e.g. shoplite-staging. Used as suffix in identity names."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "RG that holds the managed identities."
  type        = string
}

variable "oidc_issuer_url" {
  description = "AKS OIDC issuer URL. From the aks module."
  type        = string
}

variable "workloads" {
  description = <<-EOT
    Map of workload-name -> { namespace, service_account }. One UAMI and
    one federated credential will be created per entry. The federated
    credential binds the UAMI to the given Kubernetes ServiceAccount via
    the AKS OIDC issuer, enabling Workload Identity.
  EOT
  type = map(object({
    namespace       = string
    service_account = string
  }))
  default = {}
}

variable "tags" {
  description = "Tags applied to every identity."
  type        = map(string)
  default     = {}
}
