
{{/*
Common labels
*/}}
{{- define "argocd.labels" -}}
{{ include "argocd.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "argocd.selectorLabels" -}}
app.kubernetes.io/name: argocd
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "argocd.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- printf "%s-sa" "argocd" -}}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the secret store to use.
*/}}
{{- define "argocd.secretStoreName" -}}
{{- printf "%s-secret-store" "argocd" -}}
{{- end }}


