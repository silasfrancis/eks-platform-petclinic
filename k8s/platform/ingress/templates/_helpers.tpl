{{/*
_helpers.tpl for platform/ingress gateway chart.
All helpers accept a dict context with:
  name  — gateway key from the gateways map (e.g. "public", "internal")
  gw    — merged gateway config (defaults merged with instance config)
  root  — root context (.) for Release.Namespace etc
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "platform-ingress.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Generate standard resource names dynamically.
Example output: platform-ingress-public-gateway
*/}}
{{- define "platform-ingress.resourceName" -}}
{{- printf "%s-%s-gateway" (include "platform-ingress.name" .context) .gwName | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Standard Selector Labels for Istio Routing and Kubernetes tracking
*/}}
{{- define "platform-ingress.selectorLabels" -}}
app: {{ printf "%s-istio-ingressgateway" .gwName }}
istio: ingressgateway
{{- end }}

{{/*
Common Labels applied to all generated resources
*/}}
{{- define "platform-ingress.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .context.Chart.Name .context.Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{ include "platform-ingress.selectorLabels" . }}
{{- end }}

{{/* external-dns custom resources (Namespaced to prevent dependency collisions) */}}

{{/*
SecretStore name — referenced by ExternalSecret secretStoreRef
*/}}
{{- define "platform-ingress.externalDnsSecretStoreName" -}}
{{- .Values.secretStore.name | default "external-dns-secretstore" }}
{{- end }}

{{/*
ExternalSecret name
*/}}
{{- define "platform-ingress.externalDnsExternalSecretName" -}}
{{- .Values.externalSecret.name | default "external-dns-secrets" }}
{{- end }}

{{/*
Secret name — created by ExternalSecret secretStoreRef.target.name
*/}}
{{- define "platform-ingress.externalDnsSecretName" -}}
{{- .Values.externalSecret.target.name | default "external-dns-secrets" }}
{{- end }}

{{/*
Service account name for external dns secret store 
*/}}
{{- define "platform-ingress.esoServiceAccountName" -}}
{{- if .Values.esoServiceAccount -}}
  {{- .Values.esoServiceAccount.name -}}
{{- else -}}
  {{- "external-dns-secrets-sa" -}}
{{- end -}}
{{- end -}}