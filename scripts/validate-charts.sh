#!/usr/bin/env bash
# validate-charts.sh
#
# Validates all Helm charts in this repository by rendering them with
# `helm template`. This catches syntax errors, missing values, and
# invalid templates before deployment.
#
# WHAT IT DOES:
#   - Updates chart dependencies
#   - Renders all platform charts (argocd, platform/*, policies)
#   - Renders all microservices (one per values file in the env directory)
#   - Fails immediately if any chart fails to render
#   - Optionally exports rendered manifests to ./rendered/
#
# USAGE:
#   ./scripts/validate-charts.sh [ENV] [--export]
#
# ARGUMENTS:
#   ENV        Environment to validate against (default: dev)
#   --export   Write rendered manifests to ./rendered/<name>.yaml
#
# EXAMPLES:
#   ./scripts/validate-charts.sh
#   ./scripts/validate-charts.sh dev
#   ./scripts/validate-charts.sh main --export

set -euo pipefail

# Configuration

ENV=${1:-dev}
EXPORT=${2:-""}
RENDERED_DIR="rendered"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Namespaces that differ from chart name
# All other charts use their own name as the namespace
declare -A NAMESPACES=(
  [argocd]="argocd"
  [ingress]="istio-ingress"
  [compute]="karpenter"
  [monitoring]="monitoring"
  [autoscaling]="autoscaling"
  [security]="security"
  [backup]="velero"
  [policies]="kyverno"
)

# Helpers

green()  { echo -e "\033[32m  ✓ $1\033[0m"; }
red()    { echo -e "\033[31m  ✗ $1\033[0m"; }
header() { echo -e "\n\033[1;34m=== $1 ===\033[0m"; }

render() {
  local name=$1
  local chart_path=$2
  local namespace=$3
  local base_vals=$4
  local env_vals=$5

  # Render once and capture — reuse for export if needed
  local output
  if output=$(helm template "$name" "$chart_path" \
      --namespace "$namespace" \
      --values "$base_vals" \
      --values "$env_vals" 2>&1); then
    green "$name"
    if [[ "$EXPORT" == "--export" ]]; then
      echo "$output" > "${RENDERED_DIR}/${name}.yaml"
      echo -e "       \033[2m→ ${RENDERED_DIR}/${name}.yaml\033[0m"
    fi
  else
    red "$name"
    echo "$output"
    exit 1
  fi
}

# Setup

cd "${REPO_ROOT}"

[[ "$EXPORT" == "--export" ]] && mkdir -p "${RENDERED_DIR}"

echo "Validating charts [env=${ENV}$([ "$EXPORT" == "--export" ] && echo ", exporting to ${RENDERED_DIR}/")]"

# Dependencies

header "Dependencies"
for chart in k8s/argocd k8s/platform/* k8s/policies k8s/microservice; do
  if [[ -f "$chart/Chart.yaml" ]]; then
    helm dependency update "$chart"
    green "$(basename "$chart")"
  fi
done

# Platform Charts

header "Platform & Tooling"
for chart_path in k8s/argocd k8s/platform/* k8s/policies; do
  [[ -f "$chart_path/Chart.yaml" ]] || continue

  name=$(basename "$chart_path")
  base_vals="${chart_path}/values.yaml"
  env_vals="${chart_path}/values/env/${ENV}/values.yaml"
  namespace="${NAMESPACES[$name]:-$name}"

  if [[ ! -f "$env_vals" ]]; then
    red "$name — missing env values at $env_vals"
    exit 1
  fi

  render "$name" "$chart_path" "$namespace" "$base_vals" "$env_vals"
done

# Microservices 

header "Microservices"
MS_BASE="k8s/microservice"
MS_ENV_DIR="${MS_BASE}/values/env/${ENV}"

if [[ ! -d "$MS_ENV_DIR" ]]; then
  red "No microservice values found at ${MS_ENV_DIR}"
  exit 1
fi

shopt -s nullglob

for svc_vals in "${MS_ENV_DIR}"/*.yaml; do
  svc_name=$(basename "$svc_vals" .yaml)
  render "$svc_name" "$MS_BASE" "petclinic" "${MS_BASE}/values.yaml" "$svc_vals"
done

# Done

header "All charts validated for ENV=${ENV}"
