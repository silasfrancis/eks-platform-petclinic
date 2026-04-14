{{/*
Full image reference using registry + repository + digest/tag
*/}}
{{- define "microservice.image" -}}
{{- if .Values.image.digest -}}
{{- printf "%s@%s" .Values.image.repository .Values.image.digest }}
{{- else -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag }}
{{- end -}}
{{- end }}

{{/*
Common labels
*/}}
{{- define "microservice.labels" -}}
app.kubernetes.io/name: {{ .Values.appName | default .Release.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Values.image.tag | default "latest" | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Specific Annotations for Jobs/Hooks */}}
{{- define "microservice.annotations" -}}
{{- if eq .Values.controller.type "job" }}
helm.sh/hook: pre-install,pre-upgrade
helm.sh/hook-weight: "-5"
helm.sh/hook-delete-policy: before-hook-creation
argocd.argoproj.io/hook: PreSync
argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
{{- end }}
{{- end }}

{{/*
Selector labels — stable subset used by Service + PDB
*/}}
{{- define "microservice.selectorLabels" -}}
app: {{ .Values.appName }}
app.kubernetes.io/name: {{ .Values.appName }}
{{- end }}

{{/*
ServiceAccount name
*/}}
{{- define "microservice.serviceAccountName" -}}
{{- if .Values.serviceAccount.name -}}
{{- .Values.serviceAccount.name }}
{{- else -}}
{{- .Values.appName }}
{{- end -}}
{{- end }}

{{/*
Resource names
*/}}
{{- define "microservice.deploymentName" -}}
{{- printf "%s-deployment" .Values.appName }}
{{- end }}

{{- define "microservice.rolloutName" -}}
{{- printf "%s-rollout" .Values.appName }}
{{- end }}

{{- define "microservice.serviceName" -}}
{{- printf "%s-svc" .Values.appName }}
{{- end }}

{{- define "microservice.hpaName" -}}
{{- printf "%s-hpa" .Values.appName }}
{{- end }}

{{- define "microservice.pdbName" -}}
{{- printf "%s-pdb" .Values.appName }}
{{- end }}

{{- define "microservice.vsName" -}}
{{- printf "%s-vs" .Values.appName }}
{{- end }}

{{- define "microservice.drName" -}}
{{- printf "%s-dr" .Values.appName }}
{{- end }}

{{- define "microservice.secretStoreName" -}}
{{- printf "%s-secret-store" .Values.appName }}
{{- end }}

{{- define "microservice.externalSecretName" -}}
{{- printf "%s-secrets" .Values.appName }}
{{- end }}

{{- define "microservice.scaleObjectName" -}}
{{- printf "%s-scale-object" .Values.appName }}
{{- end }}


{{- define "microservice.fqdn" -}}
{{- printf "%s.%s.svc.cluster.local" (include "microservice.serviceName" .) .Release.Namespace -}}
{{- end -}}

{{/*
Common Spring Boot environment variables
Injected into every container
*/}}
{{- define "microservice.commonEnv" -}}
- name: SPRING_PROFILES_ACTIVE
  value: {{ .Values.springProfile | default "docker" | quote }}

{{/* Only inject config server URL for services that are NOT the config server */}}
{{- if .Values.configServer.enabled }}
- name: CONFIG_SERVER_URL
  value: {{ .Values.configServer.url | default "http://config-server-svc.petclinic.svc.cluster.local:8888" | quote }}
{{- end }}

{{/* Pod metadata */}}
- name: POD_NAME
  valueFrom:
    fieldRef:
      fieldPath: metadata.name
- name: POD_NAMESPACE
  valueFrom:
    fieldRef:
      fieldPath: metadata.namespace

{{/* Service-specific plain env vars */}}
{{- range $key, $val := .Values.env.plain }}
- name: {{ $key }}
  value: {{ $val | quote }}
{{- end }}
{{- end }}

{{/*
Standard probes — overrideable per service via values
*/}}
{{- define "microservice.probes" -}}
startupProbe:
  httpGet:
    path: {{ .Values.probes.startup.path | default "/actuator/health" }}
    port: {{ .Values.containerPort | default 8080 }}
  failureThreshold: {{ .Values.probes.startup.failureThreshold | default 30 }}
  periodSeconds: {{ .Values.probes.startup.periodSeconds | default 10 }}
readinessProbe:
  httpGet:
    path: {{ .Values.probes.readiness.path | default "/actuator/health" }}
    port: {{ .Values.containerPort | default 8080 }}
  initialDelaySeconds: {{ .Values.probes.readiness.initialDelaySeconds | default 10 }}
  periodSeconds: {{ .Values.probes.readiness.periodSeconds | default 5 }}
  failureThreshold: {{ .Values.probes.readiness.failureThreshold | default 3 }}
livenessProbe:
  httpGet:
    path: {{ .Values.probes.liveness.path | default "/actuator/health" }}
    port: {{ .Values.containerPort | default 8080 }}
  initialDelaySeconds: {{ .Values.probes.liveness.initialDelaySeconds | default 30 }}
  periodSeconds: {{ .Values.probes.liveness.periodSeconds | default 15 }}
  failureThreshold: {{ .Values.probes.liveness.failureThreshold | default 3 }}
{{- end }}

{{/*
Node scheduling — SPOT or ON_DEMAND
*/}}
{{- define "microservice.nodeSelector" -}}
{{- if .Values.spot.enabled }}
node-type: spot
{{- else }}
{{- toYaml .Values.nodeSelector }}
{{- end }}
{{- end }}

{{- define "microservice.tolerations" -}}
{{- if .Values.spot.enabled }}
- key: spot
  operator: Equal
  value: "true"
  effect: NoSchedule
{{- else if .Values.tolerations }}
{{- toYaml .Values.tolerations }}
{{- end }}
{{- end }}

{{- define "microservice.affinity" -}}
{{- if .Values.affinity.enabled }}
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchLabels:
            {{- include "microservice.selectorLabels" . | nindent 12 }}
        topologyKey: {{ .Values.affinity.topologyKey | default "kubernetes.io/hostname" }}
{{- end }}
{{- end }}