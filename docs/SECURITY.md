# Security

## Security Model

Defence in depth across six independent layers.
An attacker must defeat all applicable layers to compromise a workload.

| Layer | Control | Enforces |
|---|---|---|
| 1 | Cilium NetworkPolicy | Which IPs and ports can communicate |
| 2 | Istio PeerAuthentication | mTLS — encrypted + mutually authenticated |
| 3 | Istio AuthorizationPolicy | Which service identities are allowed |
| 4 | Kyverno admission control | Pod security standards at admission |
| 5 | Falco runtime detection | Suspicious behaviour in running workloads |
| 6 | Trivy continuous scanning | Known vulnerabilities in images |

## Supply Chain Security

### Image Signing

All images are signed using Cosign keyless signing tied to GitHub Actions OIDC.
No long-lived signing keys exist anywhere — the signature is cryptographically
bound to a specific workflow run on a specific branch of this repository.

```
GitHub Actions workflow executes
          │
          ▼
Fulcio (Sigstore CA) issues short-lived certificate
Certificate subject: https://github.com/silasfrancis/
  spring_boot_micro_services/.github/workflows/build-push.yaml
  @refs/heads/main
          │
          ▼
Cosign signs the image digest with the certificate
          │
          ├── Signature stored in ECR alongside image
          └── Entry written to Rekor transparency log
```

### Vulnerability Attestation

Every image produced by CI has a Trivy vulnerability report attached as a
Cosign attestation (`cosign.sigstore.dev/attestation/vuln/v1`). The report
is cryptographically bound to the image — it cannot be detached or forged.

### Admission Enforcement

Kyverno verifies both conditions at pod admission in the petclinic namespace:

1. **Signature** — must be signed by the GitHub Actions OIDC issuer for
   this repository and authorised workflow
2. **Attestation** — a valid vulnerability report attestation must exist

A pod without both is rejected before it starts. This ensures no image
can run in the cluster unless it passed through the CI pipeline.

### CI Pipeline Security Gates

```
Git push
    │
    ▼
Build multi-arch image (ARM64 + AMD64)
    │
    ▼
Trivy scan — gate on MEDIUM / HIGH / CRITICAL
    │  (accepted risks documented in .trivyignore with justification)
    ▼
Push to ECR
    │
    ▼
Cosign sign image (keyless, GitHub Actions OIDC)
    │
    ▼
Cosign attest vulnerability report
    │
    ▼
Image ready — ArgoCD picks up new tag via polling
```

## Network Security

### Default Deny

A Cilium NetworkPolicy with empty podSelector applies default-deny-all
to the petclinic namespace. Every allowed traffic path is explicit.

### mTLS

PeerAuthentication resources enforce STRICT mTLS in the petclinic and
monitoring namespaces. Istio sidecars handle certificate issuance and
rotation via istiod — no application code changes required.

### Service Identity

AuthorizationPolicy resources use cryptographic service account identity
from Istio-issued certificates — not pod labels or IP addresses which
can be spoofed. Only explicitly named service accounts can call each service.

### Allowed Traffic Map

```
Source                    Destination              Port
─────────────────────────────────────────────────────────
Istio ingress gateway  →  API Gateway              8080
API Gateway            →  Customers Service        8081
API Gateway            →  Visits Service           8082
API Gateway            →  Vets Service             8083
API Gateway            →  GenAI Service            8084
All petclinic services →  Config Server            8888
All petclinic services →  Discovery Server         8761
Customers Service      →  RDS MySQL                3306
Visits Service         →  RDS MySQL                3306
Vets Service           →  RDS MySQL                3306
Prometheus             →  All services             8080 (/actuator/prometheus)
Istio control plane    ↔  All sidecars             15012, 15014, 15017
```

Everything else is denied at L4 by Cilium before reaching the Istio proxy.

## Secrets Management

No secrets are committed to Git in any form.

| Secret | Storage location | How accessed |
|---|---|---|
| Application DB credentials | AWS Secrets Manager | ESO + IRSA |
| RDS root password | AWS Secrets Manager | Terraform remote state |
| Cloudflare API token | AWS Secrets Manager | ESO + IRSA |
| Slack webhook URLs | AWS Secrets Manager | ESO + IRSA |
| ArgoCD SSH deploy key | AWS Secrets Manager | ESO + IRSA |
| Grafana admin credentials | AWS Secrets Manager | ESO + IRSA |
| TLS certificates | cert-manager (Let's Encrypt) | Kubernetes Secret |

IRSA (IAM Roles for Service Accounts) provides AWS API access using
short-lived OIDC tokens — no static AWS credentials exist in the cluster.
Each component has a dedicated IAM role scoped to minimum required permissions.

## Pod Security Standards

All petclinic containers are required by Kyverno policy to declare:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 65532           # distroless nonroot UID
  privileged: false
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: ["ALL"]

podSecurityContext:
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault      # blocks dangerous syscalls at kernel level
```

`hostPID`, `hostIPC`, and `hostNetwork` are all disabled and enforced by
Kyverno — pods declaring these will be rejected at admission.

## Runtime Security

### Falco

Falco uses the `modern_ebpf` driver to monitor kernel syscalls without
requiring a kernel module. This works on EKS AL2023 Graviton nodes.

Custom rules in `k8s/platform/security/falco-rules/petclinic-rules.yaml`
detect petclinic-specific threats alongside the default Falco ruleset.

All Falco alerts at warning priority or above route to Slack
`#petclinic-security` via Falcosidekick.

### Trivy Operator

Continuous vulnerability scanning runs against all workloads in the
petclinic namespace — on pod creation and every 24 hours thereafter.

Compliance checks run every 6 hours against:
- EKS CIS Benchmark 1.4
- Kubernetes NSA Hardening Guide 1.0
- Kubernetes Pod Security Standards (baseline)

Scan results surface as `VulnerabilityReport` and `ConfigAuditReport`
Kubernetes resources, visible in the Grafana security dashboard.

## Dashboard Access Control

Internal dashboards (Grafana, ArgoCD, Prometheus, Loki) are served
exclusively via a private internal NLB. DNS records live in a Route53
private hosted zone — the hostnames do not resolve from the public internet.

Access requires an active WireGuard VPN connection. The VPN server is a
private EC2 instance configured via Ansible over AWS SSM. No SSH port is
open on the VPN server.

## Vulnerability Acceptance Policy

Known findings accepted as low risk are documented in `.trivyignore`
with a justification comment per entry. The `.trivyignore` in the repository
is mirrored into the Trivy Operator ConfigMap so CI and runtime scanning
use the same acceptance list.

New entries to `.trivyignore` require a brief justification in the commit
message explaining why the finding is accepted.