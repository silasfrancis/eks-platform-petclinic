{{/*
_helpers.tpl for platform/ingress gateway chart.
Provides template functions for all gateway resources:
  certificate, deployment, rbac, gateway, hpa, load-balancer, pdb, service-account
*/}}

{{/*
Common labels applied to all gateway resources
*/}}
{{- define "gateway.labels" -}}
app: istio-ingressgateway
istio: ingressgateway
"istio.io/dataplane-mode": "none"
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: platform-ingress
{{- if index .Values.labels "istio.io/dataplane-mode" }}
"istio.io/dataplane-mode": {{ index .Values.labels "istio.io/dataplane-mode" | quote }}
{{- end }}
{{- end }}

{{/*
Selector labels — used by Deployment, HPA, PDB and Service to find gateway pods
*/}}
{{- define "gateway.selectorLabels" -}}
app: istio-ingressgateway
istio: ingressgateway
{{- end }}

{{/*
Service account name
*/}}
{{- define "gateway.serviceAccountName" -}}
{{- .Values.gateway.serviceAccount.name | default "istio-ingressgateway" }}
{{- end }}

{{/*
Deployment name
*/}}
{{- define "gateway.deploymentName" -}}
{{- .Values.gateway.deployment.name | default "istio-ingressgateway" }}
{{- end }}

{{/*
Load balancer service name
*/}}
{{- define "gateway.loadBalancerName" -}}
{{- .Values.gateway.loadbalancer.name | default "istio-ingressgateway" }}
{{- end }}

{{/*
HPA name
*/}}
{{- define "gateway.hpaName" -}}
{{- .Values.gateway.hpa.name | default "istio-ingressgateway" }}
{{- end }}

{{/*
VPA name
*/}}
{{- define "gateway.vpaName" -}}
{{- .Values.gateway.vpa.name | default "istio-ingressgateway" }}
{{- end }}

{{/*
PDB name
*/}}
{{- define "gateway.pdbName" -}}
{{- .Values.gateway.pdb.name | default "istio-ingressgateway" }}
{{- end }}

{{/*
Role name
*/}}
{{- define "gateway.roleName" -}}
{{- .Values.gateway.role.name | default "istio-ingressgateway" }}
{{- end }}

{{/*
RoleBinding name
*/}}
{{- define "gateway.roleBindingName" -}}
{{- .Values.gateway.roleBinding.name | default "istio-ingressgateway" }}
{{- end }}

{{/*
Gateway resource name
*/}}
{{- define "gateway.gatewayName" -}}
{{- .Values.gateway.gateway.name | default "istio-ingressgateway" }}
{{- end }}

{{/*
Certificate name
*/}}
{{- define "gateway.certificateName" -}}
{{- .Values.gateway.certificate.name | default "istio-ingressgateway-tls" }}
{{- end }}

{{/*
Certificate secret name — referenced by Gateway tls.credentialName
Must match certificate.spec.secretName in values
*/}}
{{- define "gateway.certificateSecretName" -}}
{{- .Values.gateway.certificate.spec.secretName | default "istio-ingressgateway-tls" }}
{{- end }}

{{/*
Deployment annotations
Merges user-defined annotations with Istio injection and Prometheus scrape annotations
*/}}
{{- define "gateway.deploymentAnnotations" -}}
{{- if .Values.gateway.deployment.annotations }}
{{- toYaml .Values.gateway.deployment.annotations }}
{{- end }}
{{- end }}

{{/*
Deployment pod labels
Merges common labels with Istio sidecar injection label
*/}}
{{- define "gateway.podLabels" -}}
{{- include "gateway.selectorLabels" . }}
{{- if .Values.gateway.deployment.labels }}
{{ toYaml .Values.gateway.deployment.labels }}
{{- end }}
{{- end }}

{{/*
Gateway tolerations
*/}}
{{- define "gateway.tolerations" -}}
{{- if .Values.gateway.tolerations }}
{{- toYaml .Values.gateway.tolerations }}
{{- end }}
{{- end }}

{{/*
Container resources block
*/}}
{{- define "gateway.containerResources" -}}
requests:
  cpu: {{ .Values.gateway.resources.requests.cpu | default "100m" }}
  memory: {{ .Values.gateway.resources.requests.memory | default "128Mi" }}
limits:
  cpu: {{ .Values.gateway.resources.limits.cpu | default "1000m" }}
  memory: {{ .Values.gateway.resources.limits.memory | default "512Mi" }}
{{- end }}

{{/*
Load balancer service annotations
Combines AWS NLB annotations with ExternalDNS annotations
All annotations are defined in values — this helper just renders them cleanly
*/}}
{{- define "gateway.loadBalancerAnnotations" -}}
{{- if .Values.gateway.loadbalancer.annotations }}
{{- toYaml .Values.gateway.loadbalancer.annotations }}
{{- end }}
{{- end }}

{{/*
HPA metrics block
Renders the metrics array from values for the HPA spec
*/}}
{{- define "gateway.hpaMetrics" -}}
{{- if .Values.gateway.hpa.metrics }}
{{- toYaml .Values.gateway.hpa.metrics }}
{{- end }}
{{- end }}

{{/*
Istio Gateway Servers Spec
*/}}
{{- define "gateway.servers" -}}
{{- if .Values.gateway.gateway.servers.http.enabled }}
- port:
    number: 80
    name: http
    protocol: HTTP
  hosts:
    {{- toYaml .Values.gateway.gateway.servers.http.hosts | nindent 4 }}
  {{- if .Values.gateway.gateway.servers.http.tls.httpsRedirect }}
  tls:
    httpsRedirect: true
  {{- end }}
{{- end }}

{{- if .Values.gateway.gateway.servers.https.enabled }}
- port:
    number: 443
    name: https
    protocol: HTTPS
  hosts:
    {{- toYaml .Values.gateway.gateway.servers.https.hosts | nindent 4 }}
  tls:
    mode: {{ .Values.gateway.gateway.servers.https.tls.mode | default "SIMPLE" }}
    credentialName: {{ .Values.gateway.gateway.servers.https.tls.credentialName | default (include "gateway.certificateSecretName" .) }}
{{- end -}}
{{- end -}}

{{/*
Certificate DNS names
*/}}
{{- define "gateway.certificateDnsNames" -}}
{{- if .Values.gateway.certificate.dnsNames }}
{{- toYaml .Values.gateway.certificate.dnsNames }}
{{- end }}
{{- end }}

{{/*external-dns custom resources*/}}
{{/*
SecretStore name — referenced by ExternalSecret secretStoreRef
*/}}
{{- define "external-dns.secretStoreName" -}}
{{- .Values.secretStore.name | default "platform-ingress-secretstore" }}
{{- end }}

{{/*
ExternalSecret name — referenced by ExternalSecret secretStoreRef
*/}}
{{- define "external-dns.externalSecretName" -}}
{{- .Values.externalSecret.name | default "platform-ingress-secrets" }}
{{- end }}

{{/*irsa service account*/}}
{{/*
Service account name for external dns secret store
*/}}
{{- define "irsa.serviceAccountName" -}}
{{- .Values.irsa.serviceAccount.name | default "platform-ingress-irsa" }}
{{- end }}
