# ADR-002: One shared AKS cluster, per-env resource groups

**Date:** 2026-10-22
**Status:** Accepted

## Context

The task spec says:

> *"One shared AKS cluster with a namespace per environment; separate resource
> groups per environment for databases, Key Vaults and identities (e.g.
> rg-shoplite-staging, rg-shoplite-prod); a second cluster only with a written
> justification."*

**Region note:** Spec defaults to `germanywestcentral`. GWC refused new
AKS with `AKSCapacityHeavyUsage` (platform-wide capacity constraint).
Westeurope returned `RequestDisallowedByAzure: not accepting new customers`.
Northeurope allowed deploying but had 0 quota for every allowed SKU
family (catch-22). Settled on `swedencentral` where a proven-working
`Standard_D2s_v3` cluster already runs in another RG (DSv3 family: 4/10
vCPUs used). All resources, same code, same cost.

## Decision

- One AKS cluster, one ACR, one VNet, one Postgres private DNS zone live
  in a shared composition (`infra/envs/shared/`) and `rg-shoplite-shared`.
- Argo CD runs on the shared cluster and reconciles both `shoplite-staging`
  and `shoplite-prod` namespaces from `gitops/`.
- Each env's Postgres, Redis, Key Vault, and Workload Identity live in
  their own RG (`rg-shoplite-staging`, `rg-shoplite-prod`) and are
  provisioned by `infra/envs/staging/` and `infra/envs/prod/`.
- Env compositions read shared outputs (AKS OIDC issuer URL, DB subnet
  IDs, DNS zone ID) via `terraform_remote_state`.
- Apply order: `shared → staging → prod`. Destroy order: reverse.

## Consequences

- Matches the spec exactly — no second-cluster justification needed.
- Shared VNet + per-env delegated DB subnets (`db-staging`, `db-prod`
  inside `10.40.0.0/16`) keep each env's DB isolated at the subnet level.
- One Argo CD install, one upgrade path, one UI. Promotes staging→prod
  are a single Git edit, not two.
- Cluster-admin requires an Entra group — the deployer MUST be in
  `aks_admin_group_object_ids` or Terraform cannot install Argo CD after
  the AKS cluster comes up.
- `kubelogin` must be installed on the deployer's machine
  (`brew install Azure/kubelogin/kubelogin`) for the helm/kubernetes
  Terraform providers to authenticate.
