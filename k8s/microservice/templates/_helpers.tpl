{{/*
Full image reference using registry + repository + digest/tag
*/}}
{{- define "microservice.image" -}}
{{- if .Values.image.digest -}}
{{- printf "%s/%s@%s" .Values.image.registry .Values.image.repository .Values.image.digest }}
{{- else -}}
{{- printf "%s/%s:%s" .Values.image.registry .Values.image.repository .Values.image.tag }}
{{- end -}}
{{- end }}

{{/*
Common labels
*/}}
{{- define "microservice.labels" -}}
app: {{ .Values.appName }}
app.kubernetes.io/name: {{ .Values.appName }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: petclinic
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

{{- define "microservice.externalSecretName" -}}
{{- printf "%s-secrets" .Values.appName }}
{{- end }}

{{/*
Common Spring Boot environment variables
Injected into every container
*/}}
{{- define "microservice.commonEnv" -}}
- name: SPRING_PROFILES_ACTIVE
  value: {{ .Values.springProfile | default "kubernetes" | quote }}
- name: SPRING_CONFIG_IMPORT
  value: "optional:configserver:http://config-server-svc.petclinic.svc.cluster.local:8888"
# - name: EUREKA_CLIENT_SERVICEURL_DEFAULTZONE
#   value: "http://discovery-server-svc.petclinic.svc.cluster.local:8761/eureka"
# - name: POD_NAME
#   valueFrom:
#     fieldRef:
#       fieldPath: metadata.name
# - name: POD_NAMESPACE
#   valueFrom:
#     fieldRef:
#       fieldPath: metadata.namespace
{{- range $key, $val := .Values.env.plain }}
- name: {{ $key }}
  value: {{ $val | quote }}
{{- end }}
# {{- if .Values.externalSecret.enabled }}
# - name: placeholder
# {{- end }}
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
    path: {{ .Values.probes.readiness.path | default "/actuator/health/readiness" }}
    port: {{ .Values.containerPort | default 8080 }}
  initialDelaySeconds: {{ .Values.probes.readiness.initialDelaySeconds | default 10 }}
  periodSeconds: {{ .Values.probes.readiness.periodSeconds | default 5 }}
  failureThreshold: {{ .Values.probes.readiness.failureThreshold | default 3 }}
livenessProbe:
  httpGet:
    path: {{ .Values.probes.liveness.path | default "/actuator/health/liveness" }}
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

{{/*
Pod anti-affinity — spread pods across nodes
*/}}
{{- define "microservice.affinity" -}}
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchLabels:
            {{- include "microservice.selectorLabels" . | nindent 12 }}
        topologyKey: kubernetes.io/hostname
{{- end }}