variable "subscription_id" {
  description = "Azure subscription ID."
  type        = string
}

variable "location" {
  description = "Azure region. Per the task spec: germanywestcentral."
  type        = string
  default     = "germanywestcentral"
}

variable "aks_admin_group_object_ids" {
  description = <<-EOT
    List of Entra group object IDs granted "Azure Kubernetes Service RBAC Cluster Admin".
    For prod, keep this tight — only an on-call group should be in here.
  EOT
  type        = list(string)
  default     = []
}
