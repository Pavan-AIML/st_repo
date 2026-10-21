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
    Entra group object IDs granted cluster-admin on the shared AKS cluster.
    IMPORTANT: your own user object ID (or a group you're in) MUST be here,
    or Terraform's helm/kubernetes providers cannot authenticate to install
    Argo CD after the cluster comes up.
  EOT
  type        = list(string)
  default     = []
}
