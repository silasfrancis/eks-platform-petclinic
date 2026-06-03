{{/*
Common labels used by customer resources
*/}}
{{- define "platform-security.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: platform-security
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels used by customer resources
*/}}
{{- define "platform-security.selectorLabels" -}}
app.kubernetes.io/name: platform-security
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
ServiceAccount name
*/}}
{{- define "platform-security.serviceAccountName" -}}
{{- if .Values.serviceAccount.name -}}
{{- .Values.serviceAccount.name -}}
{{- else -}}
{{- printf "%s-sa" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}

{{/*
ClusterIssuer name
*/}}
{{- define "platform-security.clusterIssuer.name" -}}
{{- if .Values.clusterIssuer.name -}}
{{- .Values.clusterIssuer.name -}}
{{- else -}}
{{- printf "%s-cluster-issuer" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}

{{/*
Resource names
*/}}
{{- define "platform-security.ClusterSecretStoreName" -}}
{{- if .Values.ClusterSecretStore.name -}}
{{- .Values.ClusterSecretStore.name -}}
{{- else -}}
{{- printf "%s-secret-store" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}

{{- define "platform-security.externalSecretName" -}}
{{- if .Values.externalSecret.name -}}
{{- .Values.externalSecret.name -}}
{{- else -}}
{{- printf "%s-external-secrets" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end }}
{{- end }}

{{- define "platform-security.secretName" -}}
{{- if .Values.externalSecret.targetSecret -}}
{{- .Values.externalSecret.targetSecret -}}
{{- else -}}
{{- printf "%s-secrets" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}

{{/*
ACME Spec Helper for cluster issuer
*/}}
{{- define "platform-security.clusterIssuer.spec" -}}
acme:
  server: {{ .Values.clusterIssuer.acmeServer | default "https://acme-v02.api.letsencrypt.org/directory" }}
  email: {{ .Values.clusterIssuer.email | quote }}
  privateKeySecretRef:
    name: {{ .Values.clusterIssuer.privateKeySecretName | default "letsencrypt-cloudflare-account-key" }}
  solvers:
    - dns01:
        cloudflare:
          apiTokenSecretRef:
            name: {{ .Values.clusterIssuer.existingSecret.name | default "cloudflare-dns-token" }}
            key: {{ .Values.clusterIssuer.existingSecret.key | default "cloudflare-api-token" }}
{{- end -}}