# Alert routing

Alertmanager routes SLO alerts (`ShopliteApiErrorBudgetFastBurn`,
`…SlowBurn`, `…LatencyBudgetFastBurn`) via severity-based matchers.

## Current state

Routes are defined in the Alertmanager config shipped by
`kube-prometheus-stack`:

```yaml
route:
  receiver: default
  group_by: [alertname, namespace]
  routes:
    - matchers: [severity = "critical"]
      receiver: critical
receivers:
  - name: default
  - name: critical
    # Slack webhook — commented out until a real URL is wired in.
    # webhook_configs:
    #   - url: https://hooks.slack.com/services/XXX/YYY/ZZZ
```

**Right now** both receivers are empty, so alerts land in the Alertmanager
UI only (visible via `kubectl port-forward -n monitoring svc/kps-alertmanager 9093:9093`).
That satisfies the spec's *"Slack webhook, e-mail, or Alertmanager UI"* bar.

## How to add a real Slack webhook (10 min)

1. In Slack, create an **Incoming Webhook** for your channel (e.g.
   `#shoplite-oncall`). You'll get a URL like
   `https://hooks.slack.com/services/T.../B.../...`.

2. Store the URL in the shared Key Vault:
   ```bash
   az keyvault secret set --vault-name kv-shoplite-shared-… \
     --name slack-alerts-webhook \
     --value "https://hooks.slack.com/services/T.../B.../..."
   ```

3. Add an `ExternalSecret` in the `monitoring` namespace to sync it to K8s.

4. Update the Alertmanager chart values with a `webhook_configs` block that
   reads from the K8s Secret via `url_file: /etc/alertmanager/secrets/slack-url`
   (requires a volume mount — see kube-prometheus-stack docs).

5. `helm upgrade` the chart. Alertmanager hot-reloads.

## Testing

Fire a synthetic alert:

```bash
kubectl exec -n monitoring alertmanager-kps-alertmanager-0 -- \
  amtool alert add \
    --alertmanager.url=http://localhost:9093 \
    alertname=TestFire severity=critical \
    --annotation=summary="synthetic test"
```

Alert appears in the Alertmanager UI within ~5 sec. If the Slack webhook
is wired, a message lands in `#shoplite-oncall` within ~30 sec.

## For the Task 2 incident drill

When the reviewer injects a fault:

1. **Detect** — the first notification is the Alertmanager UI entry.
   `kubectl port-forward -n monitoring svc/kps-alertmanager 9093:9093` to
   check if nothing's wired to Slack yet.
2. **Record** TTD using the alert's `startsAt` timestamp
   (the Alertmanager API exposes it).
3. **Mitigate** per the runbook that matches the symptom.
4. **Record** TTM using `kubectl rollout history` or the Argo CD
   deployment timeline.
5. **Postmortem** within 24h using `docs/runbooks/postmortem-template.md`.
