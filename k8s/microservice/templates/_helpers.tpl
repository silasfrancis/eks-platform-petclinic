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
app.kubernetes.io/name: {{ .Values.appName | default .Release.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Values.image.tag | default "latest" | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Specific Annotations for services */}}
{{- define "microservice.serviceAccountAnnotations" -}}
{{- if .Values.serviceAccount.annotations }}
{{- toYaml .Values.serviceAccount.annotations }}
{{- end }}
{{- end }}

{{- /* Job hooks */}}
{{- define "microservice.workloadAnnotations" -}}
{{- /* Default Job Hooks */ -}}
{{- if eq .Values.controller.type "job" }}
helm.sh/hook: pre-install,pre-upgrade
helm.sh/hook-weight: "-5"
helm.sh/hook-delete-policy: before-hook-creation
argocd.argoproj.io/hook: PreSync
argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
{{- end }}

{{- /* Additional manual annotations from values.yaml */ -}}
{{- if .Values.job.annotations }}
{{- toYaml .Values.job.annotations | nindent 0 }}
{{- end }}
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

{{- define "microservice.jobName" -}}
{{- printf "%s-job" .Values.appName }}
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

{{- define "microservice.secretName" -}}
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
{{- if neq .Values.controller "job" }}
- name: SPRING_PROFILES_ACTIVE
  value: {{ .Values.springProfile | default "docker" | quote }}

{{/* Only inject config server URL for services that are NOT the config server */}}
{{- if .Values.configServer.enabled }}
- name: CONFIG_SERVER_URL
  value: {{ .Values.configServer.url | default "http://config-server-svc.petclinic.svc.cluster.local:8888" | quote }}
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
{{- if eq .Values.controller.type "rollout" }}
canary: 
  trafficRouting:
    istio:
      virtualService:
        name: {{ include "microservice.vsName" . }}
        routes:
          - {{ .Values.rollout.strategy.canary.trafficRouting.istio.virtualService.routes }}
      destinationRule:
        name: {{ include "microservice.drName" . }}          
        stableSubsetName: {{ .Values.rollout.strategy.canary.trafficRouting.istio.destinationRule.stableSubsetName }}
        canarySubsetName: {{ .Values.rollout.strategy.canary.trafficRouting.istio.destinationRule.canarySubsetName }}
  steps:
    {{- toYaml .Values.rollout.strategy.canary.steps | nindent 8 }}

{{- else if eq .Values.controller.type "deployment" }}
type: RollingUpdate
rollingUpdate:
  maxSurge: {{ .Values.deployment.strategy.rollingUpdate.maxSurge }}
  maxUnavailable: {{ .Values.deployment.strategy.rollingUpdate.maxUnavailable }}
{{- end }}
{{- end }}

{{/*
Default Prometheus triggers for KEDA ScaledObject.
Scales based on HTTP request rate, CPU and memory utilisation.
Uses Istio metrics for request rate — requires Istio sidecar injection.
or vector(0) prevents KEDA errors when no metrics exist yet (e.g. cold start).
*/}}
{{- define "microservice.scaleObjectBaseTriggers" -}}
- type: prometheus
  metadata:
    serverAddress: {{ .Values.scaleObject.prometheusServer | default "http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090" }}
    metricName: http_requests_total
    threshold: "10"
    query: |
      sum(rate(istio_requests_total{
        destination_service_name="{{ include "microservice.serviceName" . }}",
        destination_service_namespace="{{ .Release.Namespace }}",
        reporter="destination"
      }[2m])) or vector(0)
- type: prometheus
  metadata:
    serverAddress: {{ .Values.scaleObject.prometheusServer | default "http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090" }}
    metricName: cpu_utilization
    threshold: "70"
    query: |
      (
        avg(rate(container_cpu_usage_seconds_total{
          namespace="{{ .Release.Namespace }}",
          pod=~"{{ .Values.appName }}-.*",
          container="{{ .Values.appName }}"
        }[2m]))
        /
        avg(kube_pod_container_resource_requests{
          namespace="{{ .Release.Namespace }}",
          pod=~"{{ .Values.appName }}-.*",
          resource="cpu"
        })
      ) * 100 or vector(0)
- type: prometheus
  metadata:
    serverAddress: {{ .Values.scaleObject.prometheusServer | default "http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090" }}
    metricName: memory_utilization
    threshold: "80"
    query: |
      (
        avg(container_memory_working_set_bytes{
          namespace="{{ .Release.Namespace }}",
          pod=~"{{ .Values.appName }}-.*",
          container="{{ .Values.appName }}"
        })
        /
        avg(kube_pod_container_resource_requests{
          namespace="{{ .Release.Namespace }}",
          pod=~"{{ .Values.appName }}-.*",
          resource="memory"
        })
      ) * 100 or vector(0)
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