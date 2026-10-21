# Runbook: Restore Postgres from backup (point-in-time)

**Severity:** Incident / Emergency
**Time to execute:** ~20–40 minutes (depends on database size)
**Blast radius:** The target env is **down** during restore. Other env unaffected.
**Who can run this:** Owner on the subscription.

## When to run

- A bad migration corrupted data
- Accidental `DELETE` or `TRUNCATE` in production
- Database file corruption reported in Azure portal

Azure Postgres Flexible Server keeps 7 days of point-in-time backups
automatically (configured in `infra/modules/database/main.tf` as
`backup_retention_days = 7`). We restore by creating a **new server**
from a specific moment in time, then swap the connection.

## Prerequisites

- `az` CLI logged in with Owner
- `kubectl` context on the shared AKS cluster
- Approximate target timestamp (UTC) just before the bad event
- The env name: `staging` or `prod`

```bash
export ENV=prod                           # usually prod when restoring
export RG="rg-shoplite-${ENV}"
export OLD_SERVER="pg-shoplite-${ENV}"
export NEW_SERVER="pg-shoplite-${ENV}-restore-$(date +%s)"
export NAMESPACE="shoplite-${ENV}"
export RESTORE_TIME="2026-10-22T13:45:00Z"   # <-- EDIT: timestamp before the incident
```

## Steps

### 1. Scale app pods to zero (stop writes)

Preventing further writes while you restore keeps the recovered state consistent.

```bash
kubectl scale deploy -n $NAMESPACE \
  -l app.kubernetes.io/part-of=shoplite --replicas=0

kubectl get pod -n $NAMESPACE
# should show no shoplite pods
```

### 2. Trigger the point-in-time restore

```bash
az postgres flexible-server restore \
  --resource-group $RG \
  --name $NEW_SERVER \
  --source-server $OLD_SERVER \
  --restore-time "$RESTORE_TIME" \
  --output table
```

Takes **10–30 minutes** depending on DB size. Watch:

```bash
az postgres flexible-server show \
  --resource-group $RG \
  --name $NEW_SERVER \
  --query "state" -o tsv
```

Wait until `state` = `Ready`.

### 3. Verify the restore worked (sanity-check a known row)

Get the new FQDN:

```bash
NEW_FQDN=$(az postgres flexible-server show \
  --resource-group $RG --name $NEW_SERVER --query fullyQualifiedDomainName -o tsv)

# Password is the same as the old server (restore copies it).
PASSWORD=$(cd infra/envs/$ENV && terraform output -raw postgres_admin_password)

# Query from inside the cluster so we go over the private VNet:
kubectl debug -it -n $NAMESPACE --image=postgres:16-alpine \
  node/$(kubectl get node -o jsonpath='{.items[0].metadata.name}') -- \
  psql "host=$NEW_FQDN user=shoplite dbname=shoplite password=$PASSWORD sslmode=require" \
  -c "SELECT count(*) FROM products"
```

Confirm the count matches your expectations for `$RESTORE_TIME`.

### 4. Point the application at the restored server

Two options:

#### Option A — swap via Key Vault (preferred, no code change)

```bash
# Update the connection string secret in Key Vault:
NEW_CONN="postgresql+asyncpg://shoplite:${PASSWORD}@${NEW_FQDN}:5432/shoplite"
az keyvault secret set \
  --vault-name "kv-shoplite-${ENV}" \
  --name DATABASE_URL \
  --value "$NEW_CONN"

# Force ESO to re-sync immediately:
kubectl annotate externalsecret shoplite-secrets -n $NAMESPACE \
  force-sync="$(date +%s)" --overwrite
```

#### Option B — edit Terraform (longer, authoritative)

Edit `infra/modules/database/main.tf` to use the restored server name,
`terraform apply`. Needed only if you want the restored server to be
*the* server going forward (not just a temporary pointer).

### 5. Scale pods back up

```bash
kubectl scale deploy -n $NAMESPACE \
  -l app.kubernetes.io/part-of=shoplite --replicas=2

kubectl rollout status deploy -n $NAMESPACE \
  -l app.kubernetes.io/part-of=shoplite --timeout=5m
```

### 6. Smoke test

```bash
POD=$(kubectl get pod -n $NAMESPACE -l app.kubernetes.io/component=api \
  -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n $NAMESPACE $POD -- wget -qO- http://localhost:8000/readyz
kubectl exec -n $NAMESPACE $POD -- wget -qO- http://localhost:8000/products
```

### 7. Decide what to do with the old server

- **Keep as an audit snapshot** of the incident for 7 days. Rename
  with a `-pre-restore` suffix:
  ```bash
  # Can't rename servers in Azure. Instead, tag the old one so nobody
  # thinks it's live:
  az tag update --resource-id $(az postgres flexible-server show \
    --resource-group $RG --name $OLD_SERVER --query id -o tsv) \
    --operation Merge \
    --tags status=pre-restore-$(date +%Y%m%d) incident=INC-XXXX
  ```
- **Delete after post-incident review**, usually 7–14 days later:
  ```bash
  az postgres flexible-server delete \
    --resource-group $RG --name $OLD_SERVER --yes
  ```

### 8. File a post-incident ticket

Capture:
- What triggered the restore
- Who ran this runbook (name + timestamp)
- Target restore time + actual restore completion time
- Any discrepancy between expected and actual state

## Rollback

If the restored server has bad data too:

1. Pick an earlier `$RESTORE_TIME` (step 0 above).
2. Delete the just-created restored server:
   ```bash
   az postgres flexible-server delete --resource-group $RG --name $NEW_SERVER --yes
   ```
3. Restart from step 2.

## Known limitations

- Restores create a **new** server; you cannot restore in-place over the
  existing server.
- Minimum restore window is **5 minutes ago**. Can't restore to "30s ago"
  — Azure needs to flush WAL.
- Backup retention is 7 days (`backup_retention_days` in Terraform). To
  go further back we'd need Long-Term Retention (not configured).
- Redis state is **not** restored. If the incident involved queue data,
  that work is lost. Workers are expected to be idempotent.
