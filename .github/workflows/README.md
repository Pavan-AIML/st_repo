# CI/CD — operator notes

## What runs

Every push to `main` and every PR to `main` triggers `.github/workflows/ci.yml`:

1. **lint** — ruff check + format check on `apps/`
2. **test** — pytest smoke tests on api and worker (matrix)
3. **build-scan-sign** (matrix per app)
   - docker build
   - Syft SBOM
   - Trivy scan (fail on CRITICAL, informational on HIGH/MEDIUM)
   - Azure OIDC login (push only)
   - docker push to ACR (push only)
   - Cosign keyless sign (push only)
   - Cosign SBOM attestation (push only)
4. **deploy-staging** — currently disabled. Enable after Phase 11
   (Argo Rollouts).

## One-time GitHub repo setup

### Set repository variables (Settings → Secrets and variables → Actions → Variables)

| Variable | Value | Source |
|---|---|---|
| `AZURE_CLIENT_ID` | Entra client ID of the GitHub Actions UAMI | `terraform output` from `infra/envs/shared/` |
| `AZURE_TENANT_ID` | `9ef0183b-ac0d-4452-9c52-6c00aa861770` | `az account show --query tenantId` |
| `AZURE_SUBSCRIPTION_ID` | `3e4b93a6-966a-4d17-af62-540ffd96a13c` | — |

**No secrets** — all auth is via GitHub OIDC token exchange with Azure.

### Confirm the federated credential is in place

Terraform in `infra/envs/shared/` creates:
- A UAMI `id-wi-github-actions-shoplite`
- A federated credential on that UAMI matching
  `repo:Pavan-AIML/st_repo:ref:refs/heads/main`
- An AcrPush role assignment on `crshoplite`

If the push step fails with `AADSTS70025`, re-check that the federated
credential subject matches your branch exactly.

## Image signing — how Cosign keyless works here

- `cosign sign` uses the GitHub OIDC token as the signing identity.
- Signature + certificate + public transparency log entry are stored in
  the Sigstore public Rekor log.
- Verification side (Kyverno in Phase 10) checks that signatures match
  the GitHub Actions identity for this specific repo + workflow.
- **No private key** is generated, stored, or rotated.

## Trivy — exception mechanism

CRITICAL findings fail the pipeline. To temporarily waive one:

1. Open `.trivyignore` at the repo root.
2. Add a line like:
   ```
   CVE-2026-12345  # expires: 2026-11-15  owner: @pavan  reason: upstream fix pending
   ```
3. Open a PR, get it reviewed, merge.
4. Before the `expires` date, remove the line or extend after
   reconfirming the risk.

Lines without `# expires: YYYY-MM-DD` are flagged by a (future) sanity
check job. For now, honour the format by convention.

## Fast feedback — what runs when

| Trigger | Jobs that run | Push to ACR? | Sign? |
|---|---|---|---|
| PR to main | lint, test, build-scan-sign (minus push/sign) | ❌ | ❌ |
| Merge to main | all of the above + push + sign + attest | ✅ | ✅ |

PRs validate everything you *could* break but don't publish artifacts.
Only merges to `main` produce signed, pushed, tagged images.

## Local dry-run

Reproduce most of the pipeline locally:

```bash
# Lint
ruff check apps/

# Test
cd apps/api && pytest -v
cd ../worker && pytest -v

# Build
docker build -t shoplite-api:dev -f apps/api/Dockerfile apps/api/
docker build -t shoplite-worker:dev -f apps/worker/Dockerfile apps/worker/

# SBOM
syft shoplite-api:dev -o spdx-json=sbom-api.json

# Scan
trivy image --severity CRITICAL --exit-code 1 shoplite-api:dev
```
