# Runbook: Rotate the Postgres admin password

**Severity:** Routine / Scheduled (do during business hours)
**Time to execute:** ~15 minutes
**Blast radius:** One environment at a time. Does not affect the other env.
**Who can run this:** Anyone with Owner on the subscription + Key Vault
Secrets Officer on the env Key Vault.

## When to run

- Routine 90-day rotation
- After a suspected credential exposure (e.g. laptop stolen)
- After an engineer with Key Vault access leaves the team

## Prerequisites

- `az` CLI logged in to the right subscription
- `kubectl` context pointing at the shared AKS cluster
  (`make kubeconfig`)
- `terraform` (used to re-generate the password cleanly)
- The env name you're rotating: `staging` or `prod`

Set this once per terminal session:

```bash
export ENV=staging                        # or prod
export RG="rg-shoplite-${ENV}"
export PG_SERVER="pg-shoplite-${ENV}"
export NAMESPACE="shoplite-${ENV}"
```

## Steps

### 1. Generate a new password and update Terraform state

The password is held in Terraform state (`random_password.postgres_admin`
in the database module). Taint it to force regeneration:

```bash
cd infra/envs/$ENV
terraform taint 'module.database.random_password.postgres_admin'
terraform plan                            # should show: 1 to replace, 2 to change
```

Expect to see:
- `random_password.postgres_admin` → **replaced**
- `azurerm_postgresql_flexible_server.this` → **changed** (`administrator_password`)
- Any `azurerm_key_vault_secret.postgres_admin_password` → **changed** (Phase 5)

### 2. Apply the change

```bash
terraform apply
```

Takes ~2–3 min. The Postgres server stays available throughout — Azure
updates the admin password in place without restarting the server.

### 3. Verify the new password works

```bash
NEW_PASSWORD=$(terraform output -raw postgres_admin_password)
PG_FQDN=$(terraform output -raw postgres_server_fqdn)

# From a pod in the cluster (shell is in distroless so we use ephemeral):
kubectl debug -it -n $NAMESPACE --image=postgres:16-alpine deploy/shoplite-shoplite-api -- \
  psql "host=$PG_FQDN user=shoplite dbname=shoplite password=$NEW_PASSWORD sslmode=require" \
  -c "SELECT 1"
```

Expected output: `?column?` row with value `1`.

### 4. Confirm Key Vault was updated (Phase 5)

```bash
az keyvault secret show \
  --vault-name "kv-shoplite-${ENV}" \
  --name postgres-admin-password \
  --query "attributes.updated" -o tsv
```

Should show a timestamp within the last 5 minutes.

### 5. Confirm ESO re-synced the K8s Secret (Phase 5)

External Secrets Operator refreshes on a schedule (default 1h). To force
immediate re-sync:

```bash
kubectl annotate externalsecret shoplite-secrets -n $NAMESPACE \
  force-sync="$(date +%s)" --overwrite
```

Then verify:

```bash
kubectl get secret shoplite-secrets -n $NAMESPACE \
  -o jsonpath='{.data.DATABASE_URL}' | base64 -d | sed 's/:[^@]*@/:[REDACTED]@/'
```

Should print the connection string with `[REDACTED]` masking the
password. If the old password is still visible, ESO hasn't synced yet —
wait 30s and retry.

### 6. Roll the pods so they pick up the new secret

Pods only re-read envFrom secrets on restart. Trigger a rolling restart:

```bash
kubectl rollout restart deploy -n $NAMESPACE \
  -l app.kubernetes.io/part-of=shoplite

kubectl rollout status deploy -n $NAMESPACE \
  -l app.kubernetes.io/part-of=shoplite --timeout=5m
```

### 7. Smoke test

```bash
POD=$(kubectl get pod -n $NAMESPACE -l app.kubernetes.io/component=api \
  -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n $NAMESPACE $POD -- wget -qO- http://localhost:8000/readyz
```

Expected: `{"status":"ok"}`. `/readyz` hits Postgres, so a healthy
response means the new password works end-to-end.

### 8. Verify no 5xx errors in the last 5 minutes

```bash
kubectl logs -n $NAMESPACE -l app.kubernetes.io/component=api \
  --since=5m | grep -i "error\|5[0-9][0-9]" | head
```

Should return nothing.

## Rollback

If the new password breaks things:

1. Revert the Terraform change:
   ```bash
   cd infra/envs/$ENV
   terraform state rm 'module.database.random_password.postgres_admin'
   # Then edit state to restore the old password hash — or re-apply with
   # a hardcoded `administrator_password` matching the previous value
   # (recorded in step 0 below as a safety measure).
   ```
2. Re-apply.
3. Roll the pods again (step 6).

### Safety measure before rotation

Before step 1, record the current password to a secure note (1Password,
etc.):

```bash
cd infra/envs/$ENV
terraform output -raw postgres_admin_password
```

Delete the note after step 7 passes.

## Post-rotation

- Update the rotation log in `docs/rotations.log` (date, env, operator).
- Schedule the next rotation (90 days out) in the team calendar.
