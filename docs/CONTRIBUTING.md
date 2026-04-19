# Contributing

## Branch Strategy

| Branch | Purpose | Cluster |
|---|---|---|
| `main` | Production source of truth | main cluster |
| `dev` | Development source of truth | dev cluster |
| `feature/*` | Feature development | local / dev |

Feature branches merge to `dev` via pull request.
`dev` merges to `main` via pull request after validation in the dev cluster.

## Development Workflow

### Making Platform Changes

```bash
# 1. Create a feature branch
git checkout -b feature/your-change dev

# 2. Make changes to Helm values or templates

# 3. Lint and render templates locally
helm lint k8s/platform/monitoring
helm template monitoring k8s/platform/monitoring \
  -f k8s/platform/monitoring/values.yaml

# 4. Diff against live cluster (requires kubectl + VPN)
helm diff upgrade monitoring k8s/platform/monitoring \
  -f k8s/platform/monitoring/values.yaml \
  -n monitoring

# 5. Open PR against dev
# 6. After merge — ArgoCD syncs the dev cluster automatically
```

### Making Application Changes

```bash
# 1. Update application code in the service directory

# 2. Push to dev branch — CI handles the rest
git push origin dev

# CI pipeline:
#   Build multi-arch image (ARM64 + AMD64)
#   Trivy scan
#   Push to ECR
#   Cosign sign
#   Cosign attest vulnerability report

# 3. ArgoCD detects the new image tag and syncs
# 4. Argo Rollouts runs the canary automatically
# 5. Slack notifications confirm deployment stages
```

### Adding a New Microservice

1. Add the service entry to `k8s/policies/values.yaml` under
   `clusterPolicy.services` with port, ingressFrom, egressTo flags
2. Create `k8s/apps/microservice/values/env/dev/<service>.yaml`
3. Add the service to `argocdBootstrap.apps.microservices.services`
   in `k8s/argocd/values.yaml`
4. Add the service to the GitHub Actions build matrix
5. Create the ECR repository in Terraform

### Adding a New Platform Component

1. Create `k8s/platform/<component>/` with Chart.yaml and values.yaml
2. Add an entry to `argocdBootstrap.apps` in `k8s/argocd/values.yaml`
3. ArgoCD will create the Application and sync it on the next wave

## Helm Chart Development

```bash
# Lint a chart
helm lint k8s/apps/microservice

# Render templates locally for a specific service
helm template customers-service k8s/apps/microservice \
  -f k8s/apps/microservice/values.yaml \
  -f k8s/apps/microservice/values/env/dev/customers-service.yaml

# Diff against live cluster (VPN required)
helm diff upgrade customers-service k8s/apps/microservice \
  -f k8s/apps/microservice/values.yaml \
  -f k8s/apps/microservice/values/env/dev/customers-service.yaml \
  -n petclinic
```

## Commit Convention

```
feat: add KEDA triggers for visits-service
fix: correct VirtualService weight after canary
docs: update architecture diagram
chore: bump karpenter to 1.1.0
ci: add attestation step to build pipeline
refactor: extract gateway helpers to _helpers.tpl
```

## Secrets

Never commit secrets. Add to AWS Secrets Manager and reference via ESO.
See [SECURITY.md](SECURITY.md#secrets-management) for the secrets model.

Adding a new secret:
1. Create the secret in AWS Secrets Manager following the path convention
   `<env>/petclinic/<service>` for app secrets
2. Add an entry to the ExternalSecret `data` list in the relevant values file
3. Reference in the application via environment variable

## Updating .trivyignore

When accepting a vulnerability finding:
1. Add the CVE ID to `.trivyignore`
2. Add a comment above it with the justification
3. Include the accepted date and a review date

```
# CVE-2023-XXXXX — accepted 2024-01-15, review 2024-07-15
# Justification: affects feature X which is not used in this service.
# No fix available upstream. Monitor for fix.
CVE-2023-XXXXX
```