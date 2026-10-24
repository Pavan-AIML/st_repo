# Postmortem: INC-YYYYMMDD-NNN — <short title>

**Status:** Draft / In review / Accepted
**Severity:** SEV-{1,2,3,4}
**Owner:** @handle
**Date of incident:** YYYY-MM-DD
**Published:** YYYY-MM-DD (within 24h of resolution per Task 2 spec)

> This document is blameless. We're reconstructing what happened so the
> next engineer avoids the same trap, not assigning fault.

---

## 1. Executive summary (≤ 150 words)

What broke, when, for how long, who noticed, how we fixed it, what the
customer saw. One short paragraph.

---

## 2. Customer impact (in SLO terms)

| SLO | Target | Actual during incident | Error budget consumed |
|---|---|---|---|
| Availability (99.5% / 30d) | 0.5% errors allowed | X.X% errors | Y% of monthly budget |
| Latency (95% / 300ms / 30d) | 5% requests >300ms | X% requests >Nms | Y% of monthly budget |

- Users affected: approximate request count or percentage
- Error-budget remaining after this incident: Z%

---

## 3. Timeline (UTC)

| Time | Event | Source |
|---|---|---|
| HH:MM | **TRIGGER** — e.g. ConfigMap updated with bad downstream URL | Git / Argo CD history |
| HH:MM | **FIRST ALERT** — e.g. `ShopliteApiErrorBudgetFastBurn` fired | Alertmanager |
| HH:MM | **ACK** — oncall acknowledged in Slack | #shoplite-oncall |
| HH:MM | **ESCALATION** — paged on-call manager | PagerDuty |
| HH:MM | **MITIGATION START** — reverted ConfigMap via Git revert | GitHub |
| HH:MM | **FIX LANDED** — new pods healthy | kubectl rollout status |
| HH:MM | **RESOLVED** — SLO burn-rate back under threshold | Prometheus |

**Time to detect (TTD):** HH:MM (first alert fire – trigger)
**Time to mitigate (TTM):** HH:MM (fix landed – first alert fire)

> Per Task 2 spec: these timestamps must match Alertmanager and
> deployment history exactly. Pull from the Prometheus `ALERTS` series
> and `kubectl rollout history` — do not estimate.

---

## 4. Root cause

Describe the technical root cause in plain prose. One or two paragraphs.

Separate from the **trigger** (what change made it happen) and the
**contributing factors** (what made it worse / took longer to detect).

- **Trigger:** the specific change / event that initiated the incident
- **Root cause:** the underlying technical reason the trigger led to impact
- **Contributing factors:** anything that amplified the blast radius

---

## 5. Detection gap

Could we have caught this earlier? Honest assessment.

- Did the alert fire on the right signal?
- Could a tighter SLO threshold have caught it sooner?
- Was there a signal we were ignoring?
- Did any dashboard / log / trace show the problem before the alert fired?

---

## 6. What went well

Things to repeat next time.

- Alert fired within N minutes of impact
- Oncall was reachable
- Runbook X was accurate
- Rollback took <5 min

---

## 7. What went poorly

Not blame — process gaps.

- No runbook existed for this specific failure mode
- Alert routing missed the primary channel
- Rollback required three manual steps
- …

---

## 8. Action items

Must be concrete, assigned, and dated. 3–5 items per the spec.

| # | Action | Owner | Due | Status |
|---|---|---|---|---|
| 1 | Add Prometheus rule for downstream URL health | @pavan | 2026-MM-DD | Open |
| 2 | Document rollback-via-Git-revert in runbook | @pavan | 2026-MM-DD | Open |
| 3 | Reduce `ShopliteApiErrorBudgetFastBurn` `for:` from 2m → 1m | @pavan | 2026-MM-DD | Open |
| 4 | Add chaos experiment for this scenario | @pavan | 2026-MM-DD | Open |
| 5 | Backfill unit test for the config-change class | @pavan | 2026-MM-DD | Open |

---

## 9. Related artefacts

- Alert that fired: Alertmanager link / screenshot
- Grafana dashboard snapshot during incident
- PR that landed the fix: GitHub link
- Deployment that caused it: Argo CD history link
- Related past incidents: INC-… if any
