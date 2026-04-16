{{/* ECR Image Glob Pattern */}}
{{- define "kyverno.ecr.glob" -}}
{{- printf "%s.dkr.ecr.%s.amazonaws.com/%s/*" .Values.kyvernoPolicies.ecr.accountId .Values.kyvernoPolicies.ecr.region .Values.kyvernoPolicies.ecr.prefix -}}
{{- end -}}

{{/* GitHub Workflow Subject Builder */}}
{{- define "kyverno.github.subject" -}}
{{- $context := index . 0 -}}
{{- $workflow := index . 1 -}}
{{- printf "https://github.com/%s/%s/.github/workflows/%s@refs/heads/%s" $context.Values.kyvernoPolicies.github.org $context.Values.kyvernoPolicies.github.repo $workflow $context.Values.kyvernoPolicies.github.branch -}}
{{- end -}}

{{/*
Generates dynamic Kyverno attestors based on the buildPush and additionalWorkflows list
*/}}
{{- define "kyverno.attestors.list" -}}
{{- $dot := . -}}
{{/* Primary build-push workflow */}}
- name: attestor-primary
  cosign:
    keyless:
      identities:
        - subject: {{ include "kyverno.github.subject" (list $dot $dot.Values.kyvernoPolicies.github.workflowRef.buildPush) | quote }}
          issuer: {{ $dot.Values.kyvernoPolicies.github.tokenIssuer | quote }}
{{/* Loop through additional workflows to create additional attestors */}}
{{- range $index, $workflow := .Values.kyvernoPolicies.github.workflowRef.additionalWorkflows }}
- name: {{ printf "attestor-additional-%d" $index }}
  cosign:
    keyless:
      identities:
        - subject: {{ include "kyverno.github.subject" (list $dot $workflow) | quote }}
          issuer: {{ $dot.Values.kyvernoPolicies.github.tokenIssuer | quote }}
{{- end }}
{{- end -}}

{{/*
Generates the CEL expression logic to check all defined attestors
*/}}
{{- define "kyverno.attestations.expression" -}}
{{- $parts := list "verifyImageSignatures(image, [attestors['attestor-primary']]) > 0" -}}
{{- range $index, $workflow := .Values.kyvernoPolicies.github.workflowRef.additionalWorkflows -}}
  {{- $parts = append $parts (printf "verifyImageSignatures(image, [attestors['attestor-additional-%d']]) > 0" $index) -}}
{{- end -}}
{{- join " || " $parts -}}
{{- end -}}

{{/* NetworkPolicy Common Labels */}}
{{- define "policies.netpol.labels" -}}
protected: "true"
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}