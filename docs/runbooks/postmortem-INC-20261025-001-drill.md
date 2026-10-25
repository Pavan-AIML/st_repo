# Postmortem: INC-20261025-001 — Phase 13 drill: canary caught bad build, but for the wrong reason

**Status:** Accepted
**Severity:** SEV-3 (drill in staging, zero production impact)
**Owner:** @pavan
**Date of incident:** 2026-10-25
**Published:** 2026-10-25 (within 24h per Task 2 spec)

> This document is blameless. We're reconstructing what happened so the
> next engineer avoids the same trap, not assigning fault.

---

## 1. Executive summary

Phase 13 incident drill. We deliberately promoted an api image whose
`BAD_BUILD_ERROR_PCT=20` env var caused it to return HTTP 500 on ~20% of
`GET /products` requests. The expectation was: canary at 10% → Prometheus
analysis sees 5xx rate > 1% → Rollout aborts.

The Rollout **did** abort inside the target 5-minute window (~105s
end-to-end). But the AnalysisTemplate never actually read the 5xx rate from
Prometheus — the hardcoded Prometheus service URL in the chart
(`kube-prometheus-stack-prometheus...`) does not match the real service
(`kps-prometheus...`, because the stack is installed with
`fullnameOverride: kps`). The AnalysisRun recorded five consecutive DNS
lookup failures, which Argo Rollouts treats as a `consecutiveErrorLimit`
breach, and the Rollout aborted on that signal. The error signal we wanted
to catch was present and visible in the load generator (peak 5.2% error
window), but our analysis pipeline was blind to it.

Net: the auto-rollback path works, SRE-grade observability of the actual
SLI does not — yet. Fixing the service name turns a lucky-abort into a
real-signal abort.

---

## 2. Customer impact (in SLO terms)

Drill was run in `shoplite-staging` against synthetic load only. **Zero
real-customer impact.** Numbers below are for the synthetic load generator
and would represent the shape of a real-user impact if this had hit prod.

| SLO | Target | Actual during incident | Error budget consumed |
|---|---|---|---|
| Availability (99.5% / 30d) | ≤ 0.5% errors | peak 5.2% in one 15s window, ~2% average over the ~90s canary window | ~0.001% of monthly budget on synthetic traffic |
| Latency (p95 < 300ms / 30d) | 5% requests > 300ms | not measured — all 500s returned fast | ~0% |

- Synthetic requests during incident: ~1,500
- Synthetic requests that saw 500: ~40
- Real users affected: 0 (staging only)
- Error-budget remaining after this incident: effectively 100% (synthetic)

---

## 3. Timeline (UTC)

| Time | Event | Source |
|---|---|---|
| 01:00:04 | **TRIGGER** — Rollout patched to `shoplite-api@sha256:0c1019bf…` with `BAD_BUILD_ERROR_PCT=20` | `kubectl patch` (manual, see §7) |
| 01:00:19 | Canary ReplicaSet `shoplite-shoplite-api-85bb684555` created, 1 pod up, step 1 (`setWeight: 10`) | `kubectl get rollout` |
| 01:00:19 | `RolloutPaused` (CanaryPauseStep, 60s) | argo-rollouts controller event |
| 01:01:19 | `RolloutResumed`, step 2 `pause: 60s` completed | argo-rollouts controller event |
| 01:01:34 | **FIRST ANALYSIS MEASUREMENT** — Prom query attempt → DNS error (`no such host`) | AnalysisRun `shoplite-shoplite-api-85bb684555-2-2` |
| 01:01:34 → 01:02:14 | 4 more consecutive DNS errors (10s interval) | AnalysisRun measurements |
| 01:02:14 | **ROLLBACK TRIGGERED** — `consecutiveErrors (5) > consecutiveErrorLimit (4)` → `RolloutAborted` | argo-rollouts controller event |
| 01:02:14 | `SwitchService` — canary Service selector flipped from `85bb684555` back to `76d5cb9c49` (stable) | argo-rollouts controller event |
| 01:02:34 | Canary pod scaled to 0, stable continues at 2/2 | `kubectl get pods` |
| ~01:04:00 | Load generator back to 100% 2xx | load generator log |
| 01:05:30 | Rollout reverted to known-good image via second `kubectl patch` (drill cleanup) | manual |

**Time to detect (TTD):** ~90s (trigger at 01:00:04 → first analysis
measurement at 01:01:34 — but the measurement was a DNS error, not a 5xx
observation).
**Time to mitigate (TTM):** ~40s (first analysis error at 01:01:34 →
rollback at 01:02:14, driven by consecutiveErrorLimit).
**Total incident window:** ~105s (trigger → stable serving 100%).
**Target:** <5min per Task 2 spec. **Hit.**

---

## 4. Root cause

**Trigger.** We intentionally promoted an image signed from commit
`3deb8bc` with `BAD_BUILD_ERROR_PCT=20`, which causes ~20% of
`GET /products` to return HTTP 500 (code at `apps/api/main.py` gated by
env var).

**Root cause.** The AnalysisTemplate in
`charts/shoplite/templates/rollout-api.yaml:149` hardcodes the Prometheus
service address:

```
http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090
```

The actual service is `kps-prometheus.monitoring.svc.cluster.local:9090`,
because the kube-prometheus-stack Helm chart is installed with
`fullnameOverride: kps` (see `gitops/platform/kube-prometheus-stack.yaml`).
No one spotted this when the chart was wired up — all previous changes
only tested that the Rollout + AnalysisTemplate CRs applied, not that an
actual AnalysisRun could reach Prometheus.

**Contributing factors.**

- The AnalysisRun's `failureLimit: 1` and the implicit
  `consecutiveErrorLimit: 4` together mean "any transient Prom
  unavailability for 5 polls in a row kills a Rollout." That's the right
  default — but it masked our bug by causing a correct-looking abort.
- The chart's AnalysisTemplate was never exercised against a real failing
  canary before today. CI tests the chart renders; it does not run a
  canary end-to-end.
- SLO burn-rate alert window (5m) is longer than our canary analysis
  window (~90s). The alert never fired because the incident ended before
  it could evaluate — no cross-check on whether the abort decision agreed
  with Prometheus's view of the SLI.

---

## 5. Detection gap

We "detected" via the wrong signal.

- The 5xx rate from the bad canary **was** visible in Prometheus and in
  the load generator (`err_pct` reached 5.2% in one 15s window).
- The AnalysisTemplate's Prometheus query would have fired correctly if
  the hostname resolved. The query is correct; only the address is wrong.
- Had the bad build taken longer to abort (e.g. if `consecutiveErrorLimit`
  were higher), we would eventually have been aborted by the SLO
  burn-rate alert routing to Alertmanager — but with worse TTD.
- Nothing in our existing test setup would have caught this. The chart
  renders cleanly; the AnalysisTemplate is syntactically valid; the only
  way to see this failure is to actually run a canary against a live
  Prometheus.

---

## 6. What went well

- Canary mechanism itself worked end-to-end: 10% traffic weight routed to
  canary pod, canary pod served the real failure, stable kept serving
  clean traffic throughout, no 5xx leaked beyond the canary's share.
- Auto-rollback kicked in and completed in ~105s total — well inside the
  Task 2 spec target of <5min for a bad build.
- The load generator captured ground-truth error rates per 15s window
  independently of Argo Rollouts, so we have a check-the-checker signal
  that proved the canary was actually causing the pain we expected.
- Reverting the Rollout to the known-good image recovered staging to 2/2
  Healthy within 30s.
- No prod impact — the drill was correctly scoped to staging.

---

## 7. What went poorly

- **The abort was for the wrong reason.** If this had been a bad build
  that failed in a way Prometheus couldn't see (e.g. a correctness bug
  returning 200 with wrong body, or a 90% latency regression), the same
  config bug would have left the canary live and progressing, because the
  AnalysisRun would error-abort regardless of what the SLI said.
- **Argo CD GitOps delivery was wedged during drill setup.** A separate
  incident (see §4 contributing factors — K8s 1.33 adds
  `.status.terminatingReplicas` which Argo CD v2.12.6's OpenAPI schema
  doesn't know about) prevented auto-sync from applying the drill's
  values change. We bypassed it with direct `kubectl patch`, which means
  this drill did not actually exercise the "CI → ACR → Git bump → Argo CD
  → Rollout" promotion path end-to-end. We proved the Rollout half.
- **No pre-flight test** validates that the AnalysisTemplate can reach
  Prometheus. The chart's unit tests would have caught a typo'd query
  but not a wrong hostname.
- **SLO burn-rate alert window is too long** to be the primary signal
  for a canary-scoped incident. It needs a short-window partner, or we
  need to accept the AnalysisTemplate as the primary signal and alerts
  as a backstop.

---

## 8. Action items

| # | Action | Owner | Due | Status |
|---|---|---|---|---|
| 1 | Fix `charts/shoplite/templates/rollout-api.yaml:149` — change AnalysisTemplate Prometheus address from `kube-prometheus-stack-prometheus...` to `kps-prometheus.monitoring.svc.cluster.local:9090`. Push, re-run the drill to confirm the abort reason becomes a real 5xx observation. | @pavan | 2026-10-25 | Open |
| 2 | Promote the Prometheus service address out of the AnalysisTemplate into a chart value (`.Values.monitoring.prometheusUrl`) so it can be overridden per env and matches what's actually installed. | @pavan | 2026-10-26 | Open |
| 3 | Add a smoke test that `curl`s the AnalysisTemplate's Prometheus address from inside the cluster at chart-install time (helm hook or small Job) so a hostname mismatch fails loudly instead of silently. | @pavan | 2026-10-27 | Open |
| 4 | Upgrade Argo CD to v2.13+ (which handles K8s 1.33's `.status.terminatingReplicas`). Re-enable `ServerSideApply=true` on the staging + prod Applications. Re-run the drill with the full GitOps promotion path. | @pavan | 2026-10-28 | Open |
| 5 | Add a short-window burn-rate alert (e.g. 2m window / 10× budget) alongside the existing 5m/1h/6h alerts so canary-scoped incidents trigger a notification even when auto-rollback handles the fix. | @pavan | 2026-10-29 | Open |

---

## 9. Related artefacts

All evidence captured in `docs/evidence/phase13-drill/`:

- `01-rollout-timeline.txt` — 20-sample watcher output showing Rollout phase transitions
- `02-load-generator.txt` — per-15s window error-rate during the drill
- `03-analysisrun.yaml` — full AnalysisRun CR with the 5 DNS-error measurements
- `04-rollout-describe.txt` — `kubectl describe` showing the `RolloutAborted` event and reason

Earlier evidence from this session:

- `docs/evidence/kyverno-rejection-{staging,prod}.yaml` — Kyverno denying unsigned image deploys (Task 2 item 10 demo)
- `docs/evidence/argocd-apps-before-reinstall.yaml` — pre-reinstall snapshot of all 18 Argo CD Applications
- `docs/evidence/workload-snapshot-before-reinstall.txt` — pre-reinstall snapshot of all workloads

Related code:

- Rollout + AnalysisTemplate: `charts/shoplite/templates/rollout-api.yaml`
- SLO + burn-rate rules: `charts/shoplite/templates/prometheusrule-slo.yaml`
- Failure injection: `apps/api/main.py` (`BAD_BUILD_ERROR_PCT` env var)
- Image signed by: `.github/workflows/ci.yml` (Cosign keyless step)
