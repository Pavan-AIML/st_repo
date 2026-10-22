variable "subscription_id" {
  description = "Azure subscription ID. Required to disambiguate which subscription to deploy into."
  type        = string
}

variable "location" {
  description = "Azure region. Switched from germanywestcentral to westeurope due to AKS capacity constraints in GWC."
  type        = string
  default     = "westeurope"
}

variable "aks_admin_group_object_ids" {
  description = <<-EOT
    List of Entra group object IDs granted "Azure Kubernetes Service RBAC Cluster Admin".
    Members of these groups can kubectl exec/apply/delete. Leave empty if you only need the
    deployer (Owner on the subscription) to have access.
  EOT
  type        = list(string)
  default     = []
}
