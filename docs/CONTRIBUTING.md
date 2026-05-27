# Contributing

---

## Branch Strategy

| Branch | Purpose | Deploys to |
|---|---|---|
| `main` | Production source of truth | prod cluster |
| `dev` | Development source of truth | dev cluster |
| `feature/*` | Feature and platform changes | local / dev |

Allowed merge paths:

| From | To |
|---|---|
| `feature/*` | `dev` |
| `dev` | `main` |

Direct pull requests to `main` from any branch other than `dev` are
automatically closed by the branch policy GitHub Actions workflow.

---

## Development Workflow

### Platform Changes

```bash
# Branch from dev
git checkout dev && git pull origin dev
git checkout -b feature/<change-name>

# Make changes to Helm charts or values files

# Lint the chart
helm lint k8s/platform/monitoring

# Render manifests locally
helm template monitoring k8s/platform/monitoring \
  -f k8s/platform/monitoring/values.yaml

# Diff against live cluster (VPN required)
helm diff upgrade monitoring k8s/platform/monitoring \
  -f k8s/platform/monitoring/values.yaml \
  -n monitoring

# Push and open a PR to dev
git push origin feature/<change-name>
```

After merge to `dev`:
- ArgoCD syncs the dev cluster automatically
- Validate the change in dev before promoting to prod

After merge to `main`:
- ArgoCD syncs the prod cluster automatically

---

### Application Changes

```bash
# Branch from dev
git checkout dev && git pull origin dev
git checkout -b feature/<service-change>

# Make changes

# Push and open a PR to dev
git push origin feature/<service-change>
```

CI runs on PR:
- builds ARM64 + AMD64 images via Buildx
- runs Trivy vulnerability scan
- pushes images to ECR with immutable tags
- signs images with Cosign (keyless, GitHub OIDC)
- generates and attaches vulnerability attestation

After merge:
- Helm values file is updated with the new image tag
- ArgoCD detects the change and syncs
- Argo Rollouts manages the canary rollout automatically

---

## Adding a New Microservice

1. Add a service entry to `k8s/policies/values.yaml` under
   `clusterPolicy.services` — this generates the NetworkPolicy allow
   rules automatically.

2. Create per-service values file:
   ```
   k8s/microservice/values/env/dev/<service>.yaml
   k8s/microservice/values/env/main/<service>.yaml
   ```

3. Register the service in `k8s/argocd/values.yaml` under
   `argocdBootstrap.apps.microservices.services` — this generates
   the ArgoCD Application automatically.

4. Add the service to the GitHub Actions build matrix in
   `.github/workflows/build-push.yaml`.

5. Create the ECR repository in `terraform/modules/ecr/`.

No template changes are needed for steps 1 or 3. Both use the
policy-as-data pattern — adding a values entry is sufficient.

---

## Adding a Platform Component

1. Create the chart directory:
   ```
   k8s/platform/<component>/
   ├── Chart.yaml
   ├── values.yaml
   └── templates/
   ```

2. Register the component in `k8s/argocd/values.yaml` under
   `argocdBootstrap.apps` — ArgoCD creates and syncs the Application
   automatically.

---

## Helm Chart Development

```bash
# Lint
helm lint k8s/microservice

# Render locally
helm template customers-service k8s/microservice \
  -f k8s/microservice/values.yaml \
  -f k8s/microservice/values/env/dev/customers-service.yaml

# Diff against live cluster (VPN required)
helm diff upgrade customers-service k8s/microservice \
  -f k8s/microservice/values.yaml \
  -f k8s/microservice/values/env/dev/customers-service.yaml \
  -n petclinic
```

---

## Commit Convention

```
feat:     add KEDA triggers for visits-service
fix:      correct VirtualService canary weights
docs:     update architecture diagrams
chore:    bump Karpenter version to 1.5.0
ci:       add Cosign attestation step
refactor: extract gateway helper templates
```

---

## Secrets

Secrets are stored in AWS Secrets Manager and synced into Kubernetes
by External Secrets Operator. Never commit secrets to Git.

See [docs/SECURITY.md](SECURITY.md#secrets-management) for the full
secrets model.

### Adding a Secret

1. Create the secret in AWS Secrets Manager:
   ```
   <env>/petclinic/<service>
   ```

2. Add the secret mapping to the relevant ExternalSecret values file.

3. Reference the secret via environment variable in the workload values.

---

## Updating `.trivyignore`

When accepting a vulnerability finding, document it clearly:

```
# CVE-2024-XXXXX
# Accepted: 2025-06-01
# Review:   2025-12-01
# Reason: affected feature (gzip decompression) is not used by this service
CVE-2024-XXXXX
```

The same `.trivyignore` is used by both the CI Trivy scan and the
Trivy Operator runtime scan. A finding must be documented before it
can be accepted in either context.
