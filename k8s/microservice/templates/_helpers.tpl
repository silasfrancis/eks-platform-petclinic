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

{{/*Microservice name*/}}
{{- define "microservice.name" -}}
{{- if .Values.appName -}}
{{- .Values.appName }}
{{- else -}}
{{- .Release.Name }}
{{- end -}}
{{- end }}

{{/*
Common labels
*/}}
{{- define "microservice.labels" -}}
{{ include "microservice.selectorLabels" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Values.image.tag | default "latest" | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}


{{/*
Selector labels — used by Service and PDB to find pods
Subset of labels — only what stays stable across releases
*/}}
{{- define "microservice.selectorLabels" -}}
app: {{ include "microservice.name" . }}
app.kubernetes.io/name: {{ include "microservice.name" . }}
{{- end }}

{{/* Specific Annotations for services */}}
{{- define "microservice.serviceAccountAnnotations" -}}
{{- if .Values.serviceAccount.annotations }}
{{- toYaml .Values.serviceAccount.annotations }}
{{- end }}
{{- end }}

{{- /* Workload Annotations */ -}}
{{- define "microservice.workloadAnnotations" -}}

{{- /* 1. Handle Job Hooks (Only for Jobs) */ -}}
{{- if eq .Values.controller.type "job" }}
# helm.sh/hook: pre-install,pre-upgrade
# helm.sh/hook-weight: "-5"
# helm.sh/hook-delete-policy: before-hook-creation,hook-failed
{{- end }}

{{- /* 2. Apply Istio Envoy Resource Overrides (For Deployments and Rollouts) */ -}}
{{- if or (eq .Values.controller.type "deployment") (eq .Values.controller.type "rollout") }}
{{- if .Values.istioEnvoyOverrides.enabled }}
sidecar.istio.io/proxyCPU: {{ .Values.istioEnvoyOverrides.requests.cpu | quote }}
sidecar.istio.io/proxyMemory: {{ .Values.istioEnvoyOverrides.requests.memory | quote }}
sidecar.istio.io/proxyCPULimit: {{ .Values.istioEnvoyOverrides.limits.cpu | quote }}
sidecar.istio.io/proxyMemoryLimit: {{ .Values.istioEnvoyOverrides.limits.memory | quote }}
{{- end }}
{{- end }}

{{- /* 3. Merge Additional manual annotations from values.yaml */ -}}
{{- if .Values.annotations }}
{{- toYaml .Values.annotations | nindent 0 }}
{{- end }}

{{- end }}

{{/*
ServiceAccount name
*/}}
{{- define "microservice.serviceAccountName" -}}
{{- if .Values.serviceAccount.name -}}
{{- .Values.serviceAccount.name }}
{{- else -}}
{{- printf "%s-sa" .Values.appName }}
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

{{- define "microservice.jobName" -}}
{{- printf "%s-job" .Values.appName }}
{{- end }}

{{- define "microservice.serviceName" -}}
{{- printf "%s" .Values.appName }}
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

{{- define "microservice.secretName" -}}
{{- printf "%s-secrets" .Values.appName }}
{{- end }}

{{- define "microservice.scaleObjectName" -}}
{{- printf "%s-scale-object" .Values.appName }}
{{- end }}

{{- define "microservice.vpaName" -}}
{{- printf "%s-vpa" .Values.appName }}
{{- end }}

{{- define "microservice.serviceMonitorName" -}}
{{- printf "%s-service-monitor" .Values.appName }}
{{- end }}

{{- define "microservice.analysisTemplateName" -}}
{{- printf "%s-analysis-template" .Values.appName }}
{{- end }}

{{- define "microservice.fqdn" -}}
{{- printf "%s.%s.svc.cluster.local" (include "microservice.serviceName" .) .Release.Namespace -}}
{{- end -}}

{{/*
Common Spring Boot environment variables
Injected into every container
*/}}
{{- define "microservice.commonEnv" -}}
{{- if ne .Values.controller.type "job" }}
- name: SPRING_PROFILES_ACTIVE
  value: {{ .Values.springProfile | default "docker" | quote }}

{{/* Only inject config server URL for services that are NOT the config server */}}
{{- if .Values.configServer.enabled }}
- name: CONFIG_SERVER_URL
  value: {{ .Values.configServer.url | default "http://config-server.petclinic.svc.cluster.local:8888" | quote }}
{{- end }}
{{- if .Values.discoveryServer.enabled }}
- name: EUREKA_CLIENT_SERVICEURL_DEFAULTZONE
  value: {{ .Values.discoveryServer.url | default "http://discovery-server.petclinic.svc.cluster.local:8761" | quote }}
{{- end }}
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
{{- if .Values.env.plain }}
{{- range $key, $val := .Values.env.plain }}
- name: {{ $key }}
  value: {{ $val | quote }}
{{- end }}
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
{{- else if .Values.nodeSelector }}
{{- toYaml .Values.nodeSelector }}
{{- else }}
node-type: on-demand
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
{{- if and .Values.affinity .Values.affinity.enabled }}
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

{{/*
Deployment strategy for Canary (Argo Rollouts) or RollingUpdate (Standard Deployment)
*/}}
{{- define "microservice.strategy" -}}
{{- $root := . -}}
{{- if eq .Values.controller.type "rollout" }}
canary:
  analysis:
    templates:
      - templateName: {{ include "microservice.analysisTemplateName" $root }}
    args:
      - name: service-name
        value: {{ include "microservice.serviceName" . }}
      - name: namespace
        value: {{ .Release.Namespace }} 
      - name: canary-hash
        valueFrom:
          podTemplateHashValue: Latest
  trafficRouting:
    istio:
      virtualService:
        name: {{ include "microservice.vsName" . }}
        routes:
          {{- toYaml .Values.rollout.strategy.canary.trafficRouting.istio.virtualService.routes | nindent 10 }}
      destinationRule:
        name: {{ include "microservice.drName" . }}          
        stableSubsetName: {{ .Values.rollout.strategy.canary.trafficRouting.istio.destinationRule.stableSubsetName }}
        canarySubsetName: {{ .Values.rollout.strategy.canary.trafficRouting.istio.destinationRule.canarySubsetName }}
  steps:
    {{- range .Values.rollout.strategy.canary.steps }}
    - setWeight: {{ .weight }}
    - pause: 
        duration: {{ .pause }}
    - analysis:
        templates:
          - templateName: {{ include "microservice.analysisTemplateName" $root }}
        args:
          - name: service-name
            value: {{ include "microservice.serviceName" $root }}
          - name: namespace
            value: {{ $root.Release.Namespace }}
          - name: canary-hash
            valueFrom:
              podTemplateHashValue: Latest
    {{- end }}
    - setWeight: 100

{{- else if eq .Values.controller.type "deployment" }}
type: RollingUpdate
rollingUpdate:
  maxSurge: {{ .Values.deployment.strategy.rollingUpdate.maxSurge }}
  maxUnavailable: {{ .Values.deployment.strategy.rollingUpdate.maxUnavailable }}
{{- end }}
{{- end }}

{{/*
Default Prometheus triggers for KEDA ScaledObject.
- Scales based on HTTP request volume recorded by Istio.
- Uses 'increase()' instead of 'rate()' to count raw requests over the window.
- Includes 200 (Success) and 503 (No Healthy Upstream) codes to allow
  scale-from-zero (the 503s indicate traffic hitting the gateway while pods are at 0).
- "or vector(0)" ensures the query returns 0 instead of 'no data', 
  preventing KEDA from entering an error state during cold starts.
*/}}
{{- define "microservice.scaleObjectBaseTriggers" -}}
- type: prometheus
  metadata:
    serverAddress: {{ .Values.scaleObject.prometheusServer | default "http://monitoring-prometheus.monitoring.svc.cluster.local:9090" }}
    metricName: http_requests_total
    threshold: "10"
    activationThreshold: "1"
    query: |
      sum(increase(istio_requests_total{
        destination_service_name="{{ include "microservice.serviceName" . }}",
        destination_service_namespace="{{ .Release.Namespace }}",
        response_code=~"200|503"
      }[2m])) or vector(0)
{{- end }}

{{/*
Merge base triggers with any additional service-specific triggers.
Additional triggers are defined in scaleObject.triggers in values.yaml.
Base triggers always run — additional triggers are appended after.
*/}}
{{- define "microservice.scaleObjectTriggers" -}}
{{- include "microservice.scaleObjectBaseTriggers" . }}
{{- if .Values.scaleObject.triggers }}
{{- toYaml .Values.scaleObject.triggers | nindent 0 }}
{{- end }}
{{- end }}