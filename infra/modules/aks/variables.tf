variable "name" {
  description = "Short env name, e.g. shoplite-staging. Used in resource names."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "RG that will hold the AKS cluster and its identities."
  type        = string
}

variable "aks_subnet_id" {
  description = "ID of the subnet the AKS nodes will join. From networking module."
  type        = string
}

variable "kubernetes_version" {
  description = "AKS Kubernetes version, e.g. 1.30. Leave null to use AKS default."
  type        = string
  default     = null
}

variable "sku_tier" {
  description = "AKS control plane SKU. Free (no SLA) for assessment; Standard for prod."
  type        = string
  default     = "Free"
}

variable "tenant_id" {
  description = "Entra tenant ID — used for AAD-integrated RBAC."
  type        = string
}

variable "admin_group_object_ids" {
  description = "Entra group object IDs granted cluster-admin via Azure RBAC."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# System node pool
# ---------------------------------------------------------------------------

variable "system_node_vm_size" {
  description = "VM size for the system node pool."
  type        = string
  default     = "Standard_D2s_v3"
}

variable "system_node_count" {
  description = "Fixed node count for the system pool. Not auto-scaled."
  type        = number
  default     = 1
}

# ---------------------------------------------------------------------------
# User node pool
# ---------------------------------------------------------------------------

variable "user_node_vm_size" {
  description = "VM size for the user node pool where app pods run."
  type        = string
  default     = "Standard_D2s_v3"
}

variable "user_node_min_count" {
  description = "Minimum nodes in the user pool. Autoscaler will not go below this."
  type        = number
  default     = 1
}

variable "user_node_max_count" {
  description = "Maximum nodes in the user pool. Caps cost under HPA load tests."
  type        = number
  default     = 3
}

# ---------------------------------------------------------------------------
# Pod / service networking (CNI Overlay)
# ---------------------------------------------------------------------------

variable "pod_cidr" {
  description = "CIDR for pods. Overlay — not from the VNet. Must not overlap VNet."
  type        = string
  default     = "10.244.0.0/16"
}

variable "service_cidr" {
  description = "CIDR for ClusterIP services. Internal to the cluster."
  type        = string
  default     = "10.0.0.0/16"
}

variable "dns_service_ip" {
  description = "IP for the in-cluster CoreDNS service. Must be inside service_cidr."
  type        = string
  default     = "10.0.0.10"
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
