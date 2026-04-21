#!/usr/bin/env bash

# Renders all Helm charts and validates template output.
# Optionally exports rendered manifests to output files for inspection.
#
# Usage:
#   ./scripts/validate-charts.sh                  # dev, no export
#   ./scripts/validate-charts.sh dev              # dev, no export
#   ./scripts/validate-charts.sh dev --export     # dev, export to rendered/
#   ./scripts/validate-charts.sh main --export    # main, export to rendered/
#
# Output directory when --export is used:
#   rendered/<chart-name>.yaml

set -e

ENV=${1:-dev}
EXPORT=false
if [[ "${2}" == "--export" || "${1}" == "--export" ]]; then
  EXPORT=true
  # if --export was passed as first arg default env to dev
  [[ "${1}" == "--export" ]] && ENV=dev
fi

RENDERED_DIR="rendered"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Helpers

green()  { echo -e "\033[32m$1\033[0m"; }
red()    { echo -e "\033[31m$1\033[0m"; }
bold()   { echo -e "\033[1m$1\033[0m"; }

render() {
  local name=$1
  local output_file="${RENDERED_DIR}/${name}.yaml"
  shift

  if [[ "${EXPORT}" == "true" ]]; then
    mkdir -p "${RENDERED_DIR}"
    helm template "$@" > "${output_file}" \
      && green "  ✓ ${name} → ${output_file}" \
      || { red "  ✗ ${name} — FAILED"; exit 1; }
  else
    helm template "$@" > /dev/null \
      && green "  ✓ ${name}" \
      || { red "  ✗ ${name} — FAILED"; exit 1; }
  fi
}

# Start 

cd "${REPO_ROOT}"

bold "Validating charts for ENV=${ENV} EXPORT=${EXPORT}"
echo ""

# Dependencies

bold "Updating chart dependencies"
helm dependency update k8s/apps/microservice   --quiet && green "  ✓ microservice"
helm dependency update k8s/platform/ingress    --quiet && green "  ✓ platform/ingress"
helm dependency update k8s/platform/compute    --quiet && green "  ✓ platform/compute"
helm dependency update k8s/platform/monitoring --quiet && green "  ✓ platform/monitoring"
helm dependency update k8s/policies            --quiet && green "  ✓ policies"
echo ""

# ArgoCD 

bold "ArgoCD"
render "argocd" argocd k8s/argocd \
  --namespace argocd \
  --values k8s/argocd/values.yaml \
  --values k8s/argocd/values/clusters/${ENV}.yaml
echo ""

# Platform: Ingress

bold "Platform: Ingress"
render "platform-ingress" ingress k8s/platform/ingress \
  --namespace istio-ingress \
  --values k8s/platform/ingress/values.yaml
echo ""

# Platform: Compute (Karpenter + NodePools + FlowSchema)

bold "Platform: Compute"
render "platform-compute" compute k8s/platform/compute \
  --namespace karpenter \
  --values k8s/platform/compute/values.yaml \
  --values k8s/platform/compute/values/env/${ENV}.yaml
echo ""

# Platform: Monitoring

bold "Platform: Monitoring"
render "platform-monitoring" monitoring k8s/platform/monitoring \
  --namespace monitoring \
  --values k8s/platform/monitoring/values.yaml
echo ""

# Policies (Kyverno + NetworkPolicies)

bold "Policies"
render "policies" policies k8s/policies \
  --namespace kyverno \
  --values k8s/policies/values.yaml
echo ""

# Microservices 

SERVICES=(
  config-server
  discovery-server
  api-gateway
  customers-service
  visits-service
  vets-service
  genai-service
  admin-server
)

bold "Microservices"
for SERVICE in "${SERVICES[@]}"; do
  render "${SERVICE}" "${SERVICE}" k8s/apps/microservice \
    --namespace petclinic \
    --values k8s/apps/microservice/values.yaml \
    --values k8s/apps/microservice/values/env/${ENV}/${SERVICE}.yaml
done
echo ""

# Summary 

bold "Done — all charts rendered successfully for ENV=${ENV}"

if [[ "${EXPORT}" == "true" ]]; then
  echo ""
  echo "Rendered manifests written to ${RENDERED_DIR}/"
  ls -1 "${RENDERED_DIR}/"
fi