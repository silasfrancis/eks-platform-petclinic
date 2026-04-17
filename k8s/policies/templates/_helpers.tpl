{{/* ECR Image Glob Pattern */}}
{{- define "kyverno.ecr.glob" -}}
{{- $kyv := .Values.clusterPolicy.kyverno -}}
{{- printf "%s.dkr.ecr.%s.amazonaws.com/%s/*" $kyv.ecr.accountId $kyv.ecr.region $kyv.ecr.prefix -}}
{{- end -}}

{{/* GitHub Workflow Subject Builder */}}
{{- define "kyverno.github.subject" -}}
{{- $context := index . 0 -}}
{{- $workflow := index . 1 -}}
{{- $kyv := $context.Values.clusterPolicy.kyverno -}}
{{- printf "https://github.com/%s/%s/.github/workflows/%s@refs/heads/%s" $kyv.github.org $kyv.github.repo $workflow $kyv.github.branch -}}
{{- end -}}

{{/*
Generates dynamic Kyverno attestors based on the authorizedWorkflows list
*/}}
{{- define "kyverno.attestors.list" -}}
{{- $dot := . -}}
{{- $kyv := .Values.clusterPolicy.kyverno -}}
{{- range $index, $workflow := $kyv.github.authorizedWorkflows }}
- name: {{ printf "attestor-%d" $index }}
  cosign:
    keyless:
      identities:
        - subject: {{ include "kyverno.github.subject" (list $dot $workflow) | quote }}
          issuer: {{ $kyv.github.tokenIssuer | quote }}
{{- end }}
{{- end -}}

{{/*
Generates the CEL expression logic to check if ANY of the defined workflows signed the image.
The expression will look like: 
verifyImageSignatures(image, [attestors['attestor-0']]) > 0 || verifyImageSignatures(image, [attestors['attestor-1']]) > 0
*/}}
{{- define "kyverno.attestations.expression" -}}
{{- $kyv := .Values.clusterPolicy.kyverno -}}
{{- $parts := list -}}
{{- range $index, $workflow := $kyv.github.authorizedWorkflows -}}
  {{- $parts = append $parts (printf "verifyImageSignatures(image, [attestors['attestor-%d']]) > 0" $index) -}}
{{- end -}}
{{- join " || " $parts -}}
{{- end -}}

{{/* Kyverno Policy Common Labels */}}
{{- define "policies.kyverno.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: platform-policies
policy.kyverno.io/version: v1
{{- end -}}

{{/* NetworkPolicy Common Labels */}}
{{- define "policies.netpol.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: petclinic-network
protected: "true"
{{- end -}}

{{/*Istio policy labels*/}}
{{- define "policies.istio.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: petclinic-network
protected: "true"
{{- end -}}