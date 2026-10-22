# ADR-003: In-cluster Redis via Helm (not Azure Cache for Redis)

**Date:** 2026-10-22
**Status:** Accepted — forced by Azure retirement

## Context

ADR-001 selected Azure Cache for Redis Basic C0 as the queue backend.
On 2026-10-22, during the staging Terraform apply, Azure refused the
create with:

> *"Azure Cache for Redis is retiring, create Azure Managed Redis instance
> instead."*

Microsoft retired the whole Azure Cache for Redis product. The
replacement, **Azure Managed Redis** (Redis Enterprise under the hood),
starts at ~€200/mo for the smallest SKU — more than our entire €200
assessment budget.

## Decision

- Remove `azurerm_redis_cache` from the database Terraform module.
- Install **Bitnami Redis** (upstream Helm chart) via a new Argo CD
  Application in `gitops/platform/redis.yaml`.
- One shared Redis per cluster, two logical databases (one per env), or
  a Redis `Deployment` per env namespace (we go with per-env Deployment
  so staging and prod can scale independently and stay isolated).
- Worker reaches Redis at
  `redis-master.<env>.svc.cluster.local:6379`.

## Consequences

- **Cost:** €0 extra. Runs on the existing shared AKS node pool.
- **Isolation:** Each env gets its own Redis in its own namespace;
  NetworkPolicies continue to enforce "only worker → Redis."
- **Durability:** Bitnami Redis supports persistence via a PVC. For the
  assessment we leave it off (job queue only, workers are idempotent).
- **Operations:** We are now responsible for Redis upgrades. Low effort —
  the chart handles rolling updates on helm upgrade.
- **ADR-001 is partially superseded** by this record.
