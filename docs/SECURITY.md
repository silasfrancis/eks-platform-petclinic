# Security

## Security Model

The platform uses multiple independent controls across networking,
admission, runtime, and supply chain security.

| Layer | Control | Purpose |
|---|---|---|
| 1 | Cilium NetworkPolicy (default deny) | Blocks all ingress and egress traffic by default |
| 2 | Cilium NetworkPolicy (service rules) | Explicit service-to-service allow rules |
| 3 | Istio PeerAuthentication | STRICT mTLS between workloads |
| 4 | Istio AuthorizationPolicy | Service identity-based access control |
| 5 | Kyverno ImageValidatingPolicy | Verifies Cosign signatures and image provenance |
| 6 | Kyverno ValidatingPolicy | Enforces pod security requirements |
| 7 | Kyverno MutatingPolicy | Applies default security configuration |
| 8 | Falco | Runtime syscall monitoring with eBPF |
| 9 | Trivy Operator | Continuous vulnerability and compliance scanning |

---

# Supply Chain Security

## Image Signing

All container images are signed with Cosign using GitHub Actions OIDC.
No long-lived signing keys are stored in the repository or cluster.

```text
GitHub Actions workflow
│
▼
Fulcio issues short-lived signing certificate
│
▼
Cosign signs image digest
│
├── Signature stored alongside image in ECR
└── Transparency entry written to Rekor
```

The signature is tied to:
- repository
- workflow
- branch
- workflow run identity

---

## Vulnerability Attestation

Each image includes a Trivy vulnerability attestation attached through
Cosign.

The attestation is bound to the image digest and verified during
admission.

---

## Admission Enforcement

Kyverno validates workloads before they are admitted to the cluster.

Validation flow:

1. verify image signature
2. verify vulnerability attestation exists
3. validate pod security requirements
4. apply default mutations where required

Unsigned or non-compliant images are rejected before pod creation.

---

## CI Security Gates

```text
Git push
│
▼
Build multi-arch image (ARM64 + AMD64)
│
▼
Trivy vulnerability scan
│
▼
Push image to ECR
│
▼
Cosign sign image
│
▼
Cosign attach vulnerability attestation
│
▼
ArgoCD detects updated image tag
```

Accepted findings are documented in `.trivyignore` with justification.

---

# Network Security

## Default Deny

A namespace-wide Cilium NetworkPolicy applies default deny ingress and egress rules to the `petclinic` namespace.
All allowed traffic paths must be explicitly defined.

---

## mTLS

Istio `PeerAuthentication` resources enforce STRICT mTLS between services in the cluster.
Certificates are issued and rotated automatically by Istio.

---

## Service Identity

Istio `AuthorizationPolicy` resources use workload identity from Istio-issued certificates rather than IP addresses or pod labels.
Only explicitly allowed service accounts may communicate with a service.

---

## Allowed Traffic

```text
Source                    Destination               Port
────────────────────────────────────────────────────────
Istio ingress gateway  →  API Gateway               8080
API Gateway            →  Customers Service         8081
API Gateway            →  Visits Service            8082
API Gateway            →  Vets Service              8083
API Gateway            →  GenAI Service             8084
All services           →  Config Server             8888
All services           →  Discovery Server          8761
Application services   →  RDS MySQL                 3306
Prometheus             →  Application metrics       8080
Istio control plane    ↔  Sidecars                  15012,15014,15017
```

All other traffic is denied by Cilium before reaching the Istio proxy.

---

# Secrets Management

Secrets are not stored in Git.

AWS Secrets Manager is the primary secrets backend for the platform. External Secrets Operator (ESO) synchronizes secrets into Kubernetes using IRSA-authenticated access.

| Secret | Storage | Access Method |
|---|---|---|
| Application credentials | AWS Secrets Manager | ESO + IRSA |
| Cloudflare API token | AWS Secrets Manager | ESO + IRSA |
| Slack webhook URLs | AWS Secrets Manager | ESO + IRSA |
| ArgoCD deploy key | AWS Secrets Manager | ESO + IRSA |
| Grafana credentials | AWS Secrets Manager | ESO + IRSA |
| TLS certificates | cert-manager | Kubernetes Secret |

WireGuard keys and client configurations are currently generated and stored locally on the WireGuard EC2 instance under:

```text
/etc/wireguard/
```

This avoids distributing private VPN keys through external systems, but also means client keys are lost if the instance is rebuilt.

---

## IRSA

AWS access inside the cluster uses IAM Roles for Service Accounts (IRSA).
Each platform component has a dedicated IAM role with minimum required permissions. No static AWS credentials are stored in pods.

| Component | AWS Access |
|---|---|
| Loki | S3 log bucket |
| Velero | S3 backups + EBS snapshots |
| Karpenter | EC2 + SQS |
| External Secrets | Secrets Manager |
| ExternalDNS | Route53 |
| cert-manager | Route53 DNS validation |

---

# Pod Security Standards

Kyverno enforces baseline security requirements for workloads.
Required container settings:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 65532
  privileged: false
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL

podSecurityContext:
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault
```

The following are rejected:
- `hostPID`
- `hostIPC`
- `hostNetwork`
- privileged containers

---

# Runtime Security

## Falco

Falco uses the `modern_ebpf` driver for runtime syscall monitoring on EKS AL2023 Graviton nodes.
Custom Falco rules detect suspicious behavior specific to the platform alongside the default Falco ruleset.
Alerts are forwarded to Slack through Falcosidekick.

---

## Trivy Operator

Trivy Operator continuously scans workloads and cluster configuration.

Scans include:
- image vulnerabilities
- Kubernetes configuration audits
- CIS benchmark checks
- Pod Security Standards validation

Reports are exposed as Kubernetes resources and surfaced through Grafana.

---

# Dashboard Access

Internal dashboards are exposed only through a private internal NLB and a Route53 private hosted zone.

Services include:
- ArgoCD
- Grafana
- Prometheus
- Loki
- Goldilocks

Access requires an active WireGuard VPN connection.

The WireGuard server runs in the prod VPC and reaches the dev VPC through VPC peering.
The server is managed through AWS SSM and does not expose SSH publicly.

---

# Vulnerability Acceptance Policy

Accepted vulnerabilities are documented in `.trivyignore` with:
- CVE ID
- justification
- review date

Example:

```text
# CVE-2024-XXXX
# Accepted because feature is unused in this workload.
# Review date: 2026-12-01
CVE-2024-XXXX
```

The same `.trivyignore` rules are used by both:
- CI Trivy scans
- Trivy Operator runtime scans