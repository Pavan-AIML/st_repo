# ADR-001: Tooling choices

**Date:** 2026-10-20  
**Status:** Accepted

## Decisions

| Tool | Choice | One-line justification |
|------|--------|------------------------|
| IaC | Terraform (OpenTofu) | Industry standard, strongest Azure provider, required by task spec |
| App language | Python / FastAPI | Async-native, minimal boilerplate, team familiarity |
| Container registry | Azure Container Registry | Native AKS integration, Workload Identity support, free tier sufficient |
| PostgreSQL | Azure Database for PostgreSQL Flexible Server | Managed backups, PITR, HA — avoids in-cluster operator complexity for a junior setup |
| Redis | Azure Cache for Redis (Basic C0) | Managed, no persistence needed for job queue, cheapest tier fits budget |
| Kubernetes packaging | Helm | Templating over Kustomize; better for multi-env value overrides with a single chart |
| GitOps | Argo CD | UI visibility useful for demos; app-of-apps pattern maps cleanly to staging/prod namespaces |
| Secrets | Azure Key Vault + External Secrets Operator + Workload Identity | No static credentials anywhere; native Azure integration; no separate Vault infrastructure to run |
| Ingress | ingress-nginx | Most common, well-documented, compatible with cert-manager |
| TLS | cert-manager + Let's Encrypt | Standard, free, automated renewal |
| CI/CD (Task 2) | GitHub Actions | Repo is on GitHub; native OIDC federation to Azure; no separate runners needed |
| Image signing (Task 2) | Cosign keyless (Sigstore) | No key management; OIDC-based; integrates with GitHub Actions OIDC |
| Progressive delivery (Task 2) | Argo Rollouts | Already running Argo CD; same ecosystem; canary + automated analysis built in |
| Observability (Task 2) | kube-prometheus-stack + Loki + Tempo | Full OSS stack; Grafana included; all installable via Helm |
