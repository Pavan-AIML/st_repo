# ShopLite — Platform Assessment

**Candidate:** Pavan Kumar  
**Reviewer:** Mario Turic, Softtribe  
**Azure subscription:** Softtribe_Azure_Practical_Tasks

---

## Architecture overview

```
GitHub (GitOps source of truth)
        │
        ▼
   Argo CD (in-cluster)
        │
   ┌────┴────┐
   │         │
staging     prod
namespace   namespace
   │         │
   ▼         ▼
api (FastAPI)  +  worker (Python)
       │
  Azure Key Vault  ←  External Secrets Operator
       │
  PostgreSQL Flexible Server  +  Azure Cache for Redis
```

One AKS cluster, two namespaces (`shoplite-staging`, `shoplite-prod`).  
Separate resource groups per environment for databases, Key Vaults, and identities.

---

## How to run from zero

### Prerequisites
- `az` CLI logged in to `Softtribe_Azure_Practical_Tasks`
- `terraform` >= 1.7 (or `tofu` >= 1.6)
- `kubectl`, `helm`, `argocd` CLI

### 1. Bootstrap Terraform state (run once)
```bash
make bootstrap
```

### 2. Provision infrastructure
```bash
make up
```

### 3. Tear down
```bash
make down
```

---

## Known limitations
<!-- Updated as work progresses -->
- [ ] TODO: fill in after each phase

---

## Hour log
| Date | Hours | Phase |
|------|-------|-------|
| 2026-10-20 | 2h | Phase 0 — bootstrap & skeleton |
