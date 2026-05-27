# Security

Operational security reference for the eks-platform-petclinic platform.

---

## Table of Contents

- [Security Model](#security-model)
- [Supply Chain Security](#supply-chain-security)
  - [Image Signing](#image-signing)
  - [Vulnerability Attestation](#vulnerability-attestation)
  - [CI Security Gates](#ci-security-gates)
- [Network Security](#network-security)
  - [Default Deny](#default-deny)
  - [mTLS](#mtls)
  - [Service Identity](#service-identity)
  - [Allowed Traffic Paths](#allowed-traffic-paths)
- [Secrets Management](#secrets-management)
  - [IRSA](#irsa)
- [Pod Security Standards](#pod-security-standards)
- [Runtime Security](#runtime-security)
  - [Falco](#falco)
  - [Trivy Operator](#trivy-operator)
- [Dashboard Access](#dashboard-access)
- [Vulnerability Acceptance Policy](#vulnerability-acceptance-policy)

---

## Security Model

The platform implements multiple independent security controls across networking, admission, runtime, identity, and software supply chain layers.

| Layer | Control | What it enforces |
|---|---|---|
| 1 | Cilium NetworkPolicy (default deny) | Blocks all ingress and egress traffic by default |
| 2 | Cilium NetworkPolicy (service rules) | Explicit per-service allow rules |
| 3 | Kyverno ImageValidatingPolicy | Cosign signature and attestation verification |
| 4 | Kyverno ValidatingPolicy | Pod security requirements |
| 5 | Kyverno MutatingPolicy | Automated security context defaults |
| 6 | Istio PeerAuthentication | mTLS STRICT between all workloads |
| 7 | External Secrets Operator | AWS Secrets Manager sync — no secrets in Git |
| 8 | IRSA | Pod-level AWS identity without static credentials |
| 9 | Falco | eBPF runtime syscall monitoring |
| 10 | Trivy Operator | Continuous vulnerability and compliance scanning |

---

## Supply Chain Security

### Image Signing

All container images are signed with Cosign using keyless signing through GitHub Actions OIDC. No long-lived signing keys are stored anywhere.

```text
GitHub Actions workflow
        │
        ▼
Fulcio issues short-lived signing certificate
        │
        ▼
Cosign signs image digest
        ├── Signature stored alongside image in ECR
        └── Transparency entry written to Rekor
```

The signature is bound to the repository, workflow, branch, and workflow run identity. An image signed in a different context fails Kyverno admission verification.

### Vulnerability Attestation

Each image includes a Trivy vulnerability report attached through Cosign as a signed attestation. The attestation is bound to the image digest and verified during admission alongside the image signature.

### CI Security Gates

```text
git push
        │
        ▼
Build multi-arch image (ARM64 + AMD64)
        │
        ▼
Trivy vulnerability scan — gate on CRITICAL
        │
        ▼
Push image to ECR (immutable tag)
        │
        ▼
Cosign sign image digest
        │
        ▼
Cosign attach vulnerability attestation
        │
        ▼
Update Helm values file with new image tag
        │
        ▼
ArgoCD detects change → Kyverno verifies → pod starts
```

Accepted findings are documented in `.trivyignore` with justification and review date. The same file is used by both CI scans and Trivy Operator runtime scans.

---

## Network Security

### Default Deny

A namespace-wide Cilium NetworkPolicy applies default deny to all ingress and egress traffic in the `petclinic` namespace.

Every allowed communication path must be explicitly defined.

### mTLS

Istio `PeerAuthentication: STRICT` is applied to the `petclinic` and `monitoring` namespaces.

All pod-to-pod traffic is:
- encrypted
- mutually authenticated
- identity verified through Istio-issued certificates

Certificates are issued and rotated automatically by Istiod.

### Service Identity

Istio `AuthorizationPolicy` uses workload identity from Istio-issued certificates.

Access decisions are based on authenticated service identities rather than:
- pod IP addresses
- Kubernetes labels
- node placement

Only explicitly allowed service accounts may communicate with protected services.

### Allowed Traffic Paths

```text
Source                     Destination            Port
───────────────────────────────────────────────────────────
Istio ingress gateway  →   api-gateway            8080
api-gateway            →   customers-service      8081
api-gateway            →   visits-service         8082
api-gateway            →   vets-service           8083
api-gateway            →   genai-service          8084
All services           →   config-server          8888
All services           →   discovery-server       8761
customers, visits, vets→   RDS MySQL              3306
Prometheus             →   All services           8080
Istio control plane    ↔   Sidecars               15012,15014,15017
```

All other traffic is blocked by Cilium before reaching the Istio proxy.

---

## Secrets Management

Secrets are not stored in Git in any form.

AWS Secrets Manager acts as the centralized secrets backend for the platform. External Secrets Operator (ESO) synchronizes secrets into Kubernetes using IRSA-authenticated access.

Secrets are:
- retrieved dynamically
- injected at runtime
- excluded from manifests and values files

| Secret | Storage | Access |
|---|---|---|
| Application DB credentials | AWS Secrets Manager | ESO + IRSA |
| Cloudflare API token | AWS Secrets Manager | ESO + IRSA |
| Slack webhook URLs | AWS Secrets Manager | ESO + IRSA |
| ArgoCD deploy key | AWS Secrets Manager | ESO + IRSA |
| Grafana credentials | AWS Secrets Manager | ESO + IRSA |
| TLS certificates | cert-manager | Kubernetes Secret |

> **WireGuard keys** are generated locally on the WireGuard EC2 instance and stored under `/etc/wireguard/`. Keys are not distributed through external systems. Client configurations should be retrieved through AWS SSM before rebuilding the instance.

### IRSA

Each platform component authenticates to AWS using a dedicated IAM role mapped to its Kubernetes service account through the EKS OIDC provider.

No static AWS credentials exist inside the cluster.

| Component | AWS permissions |
|---|---|
| Loki | S3 read/write — log bucket |
| Velero | S3 read/write — backup bucket, EBS snapshots |
| Karpenter | EC2 RunInstances/TerminateInstances, SQS |
| External Secrets | Secrets Manager GetSecretValue |
| ExternalDNS (Cloudflare) | None — uses Cloudflare API token via ESO |
| ExternalDNS (Route53) | Route53 ChangeResourceRecordSets |
| cert-manager | Route53 DNS validation |

---

## Pod Security Standards

Kyverno enforces the following security context across workloads in the `petclinic` namespace.

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

The following configurations are rejected during admission:

- `hostPID: true`
- `hostIPC: true`
- `hostNetwork: true`
- `privileged: true`
- containers without resource limits

Missing security context fields are automatically injected by the Kyverno MutatingPolicy before the ValidatingPolicy executes.

---

## Runtime Security

### Falco

Falco uses the `modern_ebpf` driver for syscall monitoring on EKS AL2023 ARM64 Graviton nodes.

The DaemonSet tolerates:
- SPOT node taints
- dedicated platform node taints
- disruption-related scheduling constraints

Custom Falco rules supplement the default ruleset with platform-specific detections.

Alerts are forwarded through:
```text
Falco → Falcosidekick → Slack (#petclinic-security)
```

### Trivy Operator

Trivy Operator continuously scans cluster workloads and configuration state.

| Scan type | Schedule |
|---|---|
| Image vulnerabilities | On pod creation + every 24h |
| Kubernetes config audit | Every 6h |
| EKS CIS benchmark 1.4 | Every 6h |
| NSA hardening checks | Every 6h |
| Pod Security Standards | Every 6h |

Reports are exposed as Kubernetes custom resources and surfaced in Grafana dashboards.

---

## Dashboard Access

Internal dashboards are exposed through:
- a private internal NLB
- Route53 private hosted zones
- WireGuard-restricted routing

They do not resolve from the public internet.

Access requires an active WireGuard VPN connection.

The WireGuard server runs in a dedicated WireGuard VPC and connects
to both the prod and dev clusters through the AWS Transit Gateway.
Dev and prod environments cannot reach each other — isolation is
enforced at the TGW route table level.

| Service | URL |
|---|---|
| ArgoCD | https://argocd.lefrancis.org |
| Grafana | https://grafana.lefrancis.org |
| Prometheus | https://prometheus.lefrancis.org |
| Loki | https://loki.lefrancis.org |
| Goldilocks | https://goldilocks.lefrancis.org |

---

## Vulnerability Acceptance Policy

Accepted vulnerabilities are documented in `.trivyignore` with:
- CVE identifier
- justification
- review date

Example:

```text
# CVE-2024-XXXX
# Reason: affected feature is not used by this workload
# Review: 2026-12-01
CVE-2024-XXXX
```

The same `.trivyignore` file is used by:
- CI Trivy scans
- Trivy Operator runtime scans

A vulnerability accepted in CI must also be accepted by the runtime scanning policy.
