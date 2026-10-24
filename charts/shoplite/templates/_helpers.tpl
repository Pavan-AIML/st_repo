{{/*
Common labels applied to every resource. Follows the Kubernetes
recommended app.kubernetes.io/* label scheme so Grafana/Prometheus and
any K8s tooling can slice by them.
*/}}
{{- define "shoplite.labels" -}}
app.kubernetes.io/name: {{ include "shoplite.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: shoplite
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end }}

{{/*
Chart name — overridable via nameOverride.
*/}}
{{- define "shoplite.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Fully-qualified resource name = release + chart name (unless overridden).
Used as the base for every resource name in this chart.
*/}}
{{- define "shoplite.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "shoplite.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}

{{/*
Per-component selector labels. Pods and Services use these to find each
other. Includes a `component` label so api and worker are distinguishable.
*/}}
{{- define "shoplite.selectorLabels" -}}
app.kubernetes.io/name: {{ include "shoplite.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
ServiceAccount name — the Workload Identity binding in Azure targets
exactly this name (from infra/envs/<env>/main.tf: workloads.shoplite.service_account).
*/}}
{{- define "shoplite.serviceAccountName" -}}
{{- default "shoplite" .Values.serviceAccount.name -}}
{{- end }}

{{/*
Image reference. Kyverno verifyImages requires digest-pinned images
(repository@sha256:...). If .digest is set, use it; else fall back to :tag
(convenient for local dev where Kyverno is off).
Call: {{ include "shoplite.image" (dict "registry" .Values.image.registry "img" .Values.api.image) }}
*/}}
{{- define "shoplite.image" -}}
{{- $registry := .registry -}}
{{- $img := .img -}}
{{- if $img.digest -}}
{{ $registry }}/{{ $img.repository }}@{{ $img.digest }}
{{- else -}}
{{ $registry }}/{{ $img.repository }}:{{ $img.tag }}
{{- end -}}
{{- end }}
