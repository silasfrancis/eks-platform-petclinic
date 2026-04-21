{{/*
_helpers.tpl for platform/ingress gateway chart.
All helpers accept a dict context with:
  name  — gateway key from the gateways map (e.g. "public", "internal")
  gw    — merged gateway config (defaults merged with instance config)
  root  — root context (.) for Release.Namespace etc
*/}}

{{/*
Merge gateway instance config with defaults.
Call this at the top of each template before passing to helpers.
Usage:
  {{- $gw := include "gateway.mergeDefaults" (dict "name" $name "gw" $cfg "root" $) | fromYaml }}
*/}}
{{- define "gateway.mergeDefaults" -}}
{{- $defaults := .root.Values.gatewayDefaults }}
{{- $gw := .gw }}
{{- $merged := merge $gw $defaults }}
{{- toYaml $merged }}
{{- end }}

{{/*
Resource name — <name>-<suffix>
All resources for a gateway share the same name prefix
e.g. public → public-istio-ingressgateway
     internal → internal-istio-ingressgateway
*/}}
{{- define "gateway.resourceName" -}}
{{- printf "%s-istio-ingressgateway" .name }}
{{- end }}

{{/*
Common labels applied to all resources for a given gateway instance
*/}}
{{- define "gateway.labels" -}}
app: {{ include "gateway.resourceName" . }}
istio: {{ include "gateway.resourceName" . }}
app.kubernetes.io/name: {{ include "gateway.resourceName" . }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
app.kubernetes.io/part-of: platform-ingress
app.kubernetes.io/instance: {{ .name }}
"istio.io/dataplane-mode": "none"
{{- end }}

{{/*
Selector labels — must be unique per gateway deployment
Used by HPA, PDB, Service to find the correct pods
*/}}
{{- define "gateway.selectorLabels" -}}
app: {{ include "gateway.resourceName" . }}
istio: {{ include "gateway.resourceName" . }}
{{- end }}

{{/*
Service account name
*/}}
{{- define "gateway.serviceAccountName" -}}
{{- include "gateway.resourceName" . }}
{{- end }}

{{/*
Certificate name
*/}}
{{- define "gateway.certificateName" -}}
{{- printf "%s-tls-cert" (include "gateway.resourceName" .) }}
{{- end }}

{{/*
Certificate secret name — referenced by Gateway tls.credentialName
Falls back to resourceName-tls if not explicitly set
*/}}
{{- define "gateway.certificateSecretName" -}}
{{- .gw.certificate.spec.secretName | default (printf "%s-tls" (include "gateway.resourceName" .)) }}
{{- end }}

{{/*
Deployment annotations
*/}}
{{- define "gateway.deploymentAnnotations" -}}
{{- $defaults := .root.Values.gatewayDefaults.deployment.annotations }}
{{- $override := .gw.deployment.annotations | default dict }}
{{- merge $override $defaults | toYaml }}
{{- end }}

{{/*
VPA name
*/}}
{{- define "gateway.vpaName" -}}
{{- printf "%s-vpa" (include "gateway.resourceName" .) }}
{{- end }}

{{/*
Load balancer service name
Updated to match new context pattern
*/}}
{{- define "gateway.loadBalancerName" -}}
{{- printf "%s-lb" (include "gateway.resourceName" .) }}
{{- end }}

{{/*
Pod labels — selector labels + injection label
*/}}
{{- define "gateway.podLabels" -}}
{{- include "gateway.selectorLabels" . }}
{{- $defaults := .root.Values.gatewayDefaults.deployment.labels | default dict }}
{{- $override := .gw.deployment.labels | default dict }}
{{- $merged := merge $override $defaults }}
{{- if $merged }}
{{ toYaml $merged }}
{{- end }}
{{- end }}

{{/*
Container resources — merge instance over defaults
*/}}
{{- define "gateway.containerResources" -}}
{{- $defaults := .root.Values.gatewayDefaults.resources }}
{{- $override := .gw.resources | default dict }}
{{- merge $override $defaults | toYaml }}
{{- end }}

{{/*
Load balancer annotations
*/}}
{{- define "gateway.loadBalancerAnnotations" -}}
{{- if .gw.loadbalancer.annotations }}
{{- toYaml .gw.loadbalancer.annotations }}
{{- end }}
{{- end }}

{{/*
HPA metrics — merge instance over defaults
*/}}
{{- define "gateway.hpaMetrics" -}}
{{- $defaults := .root.Values.gatewayDefaults.hpa.metrics }}
{{- $override := .gw.hpa.metrics | default list }}
{{- if $override }}
{{- toYaml $override }}
{{- else }}
{{- toYaml $defaults }}
{{- end }}
{{- end }}

{{/*
Tolerations — merge instance over defaults
*/}}
{{- define "gateway.tolerations" -}}
{{- $defaults := .root.Values.gatewayDefaults.tolerations | default list }}
{{- $override := .gw.tolerations | default list }}
{{- concat $defaults $override | toYaml }}
{{- end }}

{{/*
Istio Gateway servers spec
Builds the servers array from the gateway.servers config
*/}}
{{- define "gateway.servers" -}}
{{- with .gw.gateway.servers }}
{{- if .http.enabled }}
- port:
    number: 80
    name: http
    protocol: HTTP
  hosts:
    {{- toYaml .http.hosts | nindent 4 }}
  {{- if .http.tls.httpsRedirect }}
  tls:
    httpsRedirect: true
  {{- end }}
{{- end }}
{{- if .https.enabled }}
- port:
    number: 443
    name: https
    protocol: HTTPS
  hosts:
    {{- toYaml .https.hosts | nindent 4 }}
  tls:
    mode: {{ .https.tls.mode | default "SIMPLE" }}
    credentialName: {{ .https.tls.credentialName | default (include "gateway.certificateSecretName" $) }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Certificate DNS names
*/}}
{{- define "gateway.certificateDnsNames" -}}
{{- $defaults := .root.Values.gatewayDefaults.certificate.dnsNames }}
{{- $override := .gw.certificate.dnsNames | default list }}
{{- if $override }}
{{- toYaml $override }}
{{- else }}
{{- toYaml $defaults }}
{{- end }}
{{- end }}

{{/*external-dns custom resources*/}}
{{/*
SecretStore name — referenced by ExternalSecret secretStoreRef
*/}}
{{- define "external-dns.secretStoreName" -}}
{{- .Values.secretStore.name | default "external-dns-secretstore" }}
{{- end }}

{{/*
ExternalSecret name
*/}}
{{- define "external-dns.externalSecretName" -}}
{{- .Values.externalSecret.name | default "external-dns-secrets" }}
{{- end }}

{{/*
Secret name — created by ExternalSecret secretStoreRef.target.name
*/}}
{{- define "external-dns.secretName" -}}
{{- .Values.externalSecret.target.name | default "external-dns-secrets" }}
{{- end }}


{{/*
Service account name for external dns secret store
*/}}
{{- define "external-dns.serviceAccountName" -}}
{{- if .Values.esoServiceAccount -}}
  {{- .Values.esoServiceAccount.name | default "external-dns-sa" -}}
{{- else -}}
  {{- "external-dns-sa" -}}
{{- end -}}
{{- end -}}