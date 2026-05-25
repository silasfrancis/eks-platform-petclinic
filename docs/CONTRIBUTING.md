# Contributing

## Branch Strategy

| Branch | Purpose | Target Environment |
|---|---|---|
| `main` | Production source of truth | prod cluster |
| `dev` | Development source of truth | dev cluster |
| `feature/*` | Feature and platform changes | local / dev |

Branch rules are enforced through GitHub Actions.

Allowed merge paths:

| From | To |
|---|---|
| `feature/*` | `dev` |
| `dev` | `main` |

Direct pull requests to `main` are blocked unless they originate from
`dev`.

---

# Development Workflow

## Platform Changes

```bash
# Create a feature branch from dev
git checkout dev
git pull origin dev
git checkout -b feature/<change-name>

# Make changes to Helm charts or values

# Lint the chart
helm lint k8s/platform/monitoring

# Render manifests locally
helm template monitoring k8s/platform/monitoring \
  -f k8s/platform/monitoring/values.yaml

# Compare against the live cluster (VPN required)
helm diff upgrade monitoring k8s/platform/monitoring \
  -f k8s/platform/monitoring/values.yaml \
  -n monitoring

# Push the branch
git push origin feature/<change-name>
```

Open a pull request:

```txt
feature/* → dev
```

After merge:
- ArgoCD syncs the dev cluster automatically
- changes are validated in dev before promotion to production

Production deployments flow through:

```txt
dev → main
```

---

## Application Changes

```bash
# Create a feature branch
git checkout dev
git pull origin dev
git checkout -b feature/<service-change>

# Update application code

# Push branch
git push origin feature/<service-change>
```

Open a pull request:

```txt
feature/* → dev
```

CI pipeline actions:
- build ARM64 and AMD64 images
- run Trivy scans
- push images to ECR
- sign images with Cosign
- generate vulnerability attestations

After merge:
- automated Helm update PRs are created
- ArgoCD detects image updates
- Argo Rollouts handles canary deployment

---

## Adding a New Microservice

1. Add the service entry to:

```txt
k8s/policies/values.yaml
```

under:

```yaml
clusterPolicy.services
```

2. Create:

```txt
k8s/microservice/values/env/dev/<service>.yaml
```

3. Add the service to:

```txt
k8s/argocd/values.yaml
```

under:

```yaml
argocdBootstrap.apps.microservices.services
```

4. Add the service to the GitHub Actions build matrix

5. Create the ECR repository in Terraform

---

## Adding a Platform Component

1. Create:

```txt
k8s/platform/<component>/
```

2. Add:
- `Chart.yaml`
- `values.yaml`
- templates

3. Register the component in:

```txt
k8s/argocd/values.yaml
```

under:

```yaml
argocdBootstrap.apps
```

ArgoCD creates and syncs the application automatically.

---

# Helm Chart Development

```bash
# Lint chart
helm lint k8s/microservice/charts

# Render manifests locally
helm template customers-service k8s/microservice/charts \
  -f k8s/microservice/values.yaml \
  -f k8s/microservice/values/env/dev/customers-service.yaml

# Compare against live cluster (VPN required)
helm diff upgrade customers-service k8s/microservice/charts \
  -f k8s/microservice/values.yaml \
  -f k8s/microservice/values/env/dev/customers-service.yaml \
  -n petclinic
```

---

# Commit Convention

```txt
feat: add KEDA triggers for visits-service
fix: correct VirtualService canary weights
docs: update architecture diagrams
chore: bump karpenter version
ci: add Cosign attestation step
refactor: extract gateway helper templates
```

---

# Secrets

Secrets are stored in AWS Secrets Manager and synced into Kubernetes
through External Secrets Operator.

Never commit secrets to Git.

See:

```txt
docs/SECURITY.md#secrets-management
```

---

## Adding a Secret

1. Create the secret in AWS Secrets Manager:

```txt
<env>/petclinic/<service>
```

2. Add the secret mapping to the relevant ExternalSecret values file

3. Reference the secret through environment variables in the workload

---

# Updating `.trivyignore`

When accepting a vulnerability finding:

1. Add the CVE to `.trivyignore`
2. Document the reason
3. Include review and expiry dates

Example:

```txt
# CVE-2023-XXXXX
# Accepted: 2024-01-15
# Review: 2024-07-15
# Reason: affected feature is not used by this service
CVE-2023-XXXXX
```