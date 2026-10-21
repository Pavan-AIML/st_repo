output "cluster_id" {
  description = "AKS cluster resource ID."
  value       = azurerm_kubernetes_cluster.this.id
}

output "cluster_name" {
  description = "AKS cluster name — used with az aks get-credentials."
  value       = azurerm_kubernetes_cluster.this.name
}

output "node_resource_group" {
  description = "The MC_* resource group AKS auto-creates for nodes, LBs, disks."
  value       = azurerm_kubernetes_cluster.this.node_resource_group
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL. Workload Identity federated credentials point at this."
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "kubelet_identity_object_id" {
  description = "Object ID of the kubelet identity. Grant AcrPull on the registry."
  value       = azurerm_user_assigned_identity.kubelet.principal_id
}

output "kubelet_identity_client_id" {
  description = "Client ID of the kubelet identity."
  value       = azurerm_user_assigned_identity.kubelet.client_id
}

output "cluster_identity_principal_id" {
  description = "Principal ID of the cluster control-plane identity."
  value       = azurerm_user_assigned_identity.cluster.principal_id
}

output "kube_config_raw" {
  description = "Raw kubeconfig. Sensitive — never commit or print."
  value       = azurerm_kubernetes_cluster.this.kube_config_raw
  sensitive   = true
}
