# Architecture

## Overview

Kubernetes platform on AWS EKS built around the [Spring PetClinic](https://github.com/spring-petclinic/spring-petclinic-microservices) microservices application.

<!-- Hero diagrams — visual overview -->
![AWS Infrastructure Architecture](diagrams/aws-architecture.drawio.svg)
*AWS infrastructure — VPC layout, EKS cluster, VPC peering, IRSA, RDS backup automation*

![EKS Platform Architecture](diagrams/eks-platform-architecture.drawio.svg)
*Platform layers — supply chain, service mesh, security model, observability, GitOps*

---

## How to Read This Document

The platform is described from the infrastructure layer upward:

1. Multi-environment networking
2. Platform access paths
3. Traffic flow inside the cluster
4. Application architecture
5. Scaling model
6. Observability and operations
7. Security enforcement
8. CI/CD and GitOps delivery
9. Secrets and disaster recovery
10. Design decisions

---

## Multi-Environment Setup

Two environments run as independent EKS clusters in separate VPCs.
A single WireGuard server in the prod VPC provides access to both clusters. ArgoCD on the prod cluster manages both environments.

```
Prod VPC — 10.0.0.0/16              Dev VPC — 10.1.0.0/16
┌───────────────────────┐            ┌──────────────────────┐
│                       │            │                      │
│  Public subnets       │            │  Public subnets      │
│  ├── WireGuard EC2    │◄──peering─►│  ├── External NLB    │
│  ├── External NLB     │            │  └── NAT Gateway     │
│  └── NAT Gateway      │            │                      │
│                       │            │  Private subnets     │
│  Private subnets      │            │  ├── EKS nodes       │
│  └── EKS nodes        │            │  └── Internal NLB    │
│                       │            │                      │
│  Data subnets         │            │  Data subnets        │
│  └── RDS primary      │            │  └── RDS standby     │
│                       │            │                      │
│  Internal NLB         │            └──────────────────────┘
│                       │
└───────────────────────┘
```

### VPC Peering

A single peering connection between prod (10.0.0.0/16) and dev (10.1.0.0/16) serves two purposes:

**1. WireGuard access to both clusters**
```
Engineer laptop
    │ WireGuard VPN UDP 51820
    ▼
WireGuard EC2 (prod VPC, public subnet, Elastic IP)
    │
    ├──────────────────────► Prod EKS API (prod private subnet)
    │
    └──► VPC Peering ──────► Dev EKS API (dev private subnet)

Client AllowedIPs = 10.0.0.0/16, 10.1.0.0/16, 10.10.0.0/24
```

**2. ArgoCD multi-cluster management**
```
ArgoCD (prod cluster)
    │
    ├── manages prod applications  (in-cluster, direct)
    │
    └── manages dev applications   (remote, via VPC peering)
                                    dev EKS allows 443 from prod VPC CIDR
```

---

## HOW USERS AND ENGINEERS ACCESS THE PLATFORM

Two separate entry points — public traffic and internal admin traffic are handled by completely separate NLBs and Istio Gateways.

```
┌──────────────────────────────────────────┐  ┌────────────────────────────────────┐
│  PUBLIC TRAFFIC                          │  │  INTERNAL / ADMIN TRAFFIC          │
│                                          │  │                                    │
│  Anyone on the internet                  │  │  Engineers only (VPN required)     │
│          │                               │  │          │                         │
│          ▼                               │  │          ▼                         │
│  Cloudflare DNS                          │  │  WireGuard VPN                     │
│  (public A record → External NLB IP)     │  │  EC2 · public subnet               │
│          │                               │  │  Configured via Ansible over SSM   │
│          ▼                               │  │  No SSH port open                  │
│  External NLB (public subnet)            │  │          │                         │
│  internet-facing · port 443              │  │          ▼                         │
│          │                               │  │  Route53 Private Hosted Zone       │
│          ▼                               │  │  Resolves only inside VPC          │
│  Istio PUBLIC Gateway                    │  │          │                         │
│  TLS terminated · wildcard cert          │  │          ▼                         │
│  cert-manager · Let's Encrypt DNS-01     │  │  Internal NLB (private subnet)     │
│          │                               │  │  Not reachable from internet       │
│          ▼                               │  │          │                         │
│  petclinic.lefrancis.org                 │  │          ▼                         │
│  PetClinic application (8 services)      │  │  Istio INTERNAL Gateway            │
│                                          │  │  TLS terminated · same wildcard    │
│                                          │  │          │                         │
│                                          │  │          ▼                         │
│                                          │  │  grafana.lefrancis.org  → Grafana  │
│                                          │  │  argocd.lefrancis.org   → ArgoCD   │
│                                          │  │  prometheus.lefrancis.org→ Prom.   │
│                                          │  │  loki.lefrancis.org     → Loki     │
└──────────────────────────────────────────┘  └────────────────────────────────────┘
              │                                                  │
              └──────────────► cert-manager ◄────────────────────┘
                               Let's Encrypt DNS-01
                               Cloudflare API token via ESO

DNS automation:
  ExternalDNS (Cloudflare) → public A record  → petclinic.lefrancis.org
  ExternalDNS (Route53)    → private A records → all dashboard hostnames
  Two independent instances, each with its own annotation filter.
```

---

## HOW TRAFFIC ROUTES INSIDE THE CLUSTER

Every pod has an Istio sidecar (Envoy proxy) injected automatically.
All inter-service traffic flows through these proxies — encryption, traffic splitting, and policy enforcement without application code changes.

```
Request arrives at Istio Gateway
        │
        ▼
VirtualService — routes by path prefix:
  /api/customer/*  →  customers-service
  /api/visit/*     →  visits-service
  /api/vet/*       →  vets-service
  /api/genai/*     →  genai-service
  /*               →  api-gateway (catch-all)

During canary release (Argo Rollouts manages VirtualService weights):
  Normal:  100% → stable pods
  Canary:   80% → stable pods  +  20% → canary pods (new version)
              ↓                        ↓
          stable-svc             canary-svc
       (DestinationRule)      (DestinationRule)

ArgoCD ignoreDifferences on VirtualService weights prevents sync conflicts while a canary is active.

All pod-to-pod traffic:
  PeerAuthentication: STRICT — mTLS enforced everywhere
  AuthorizationPolicy: cryptographic service account identity,
  not IP-based — only explicitly named accounts may call each service
```

---

## THE APPLICATION

Eight Spring Boot microservices deployed to the `petclinic` namespace.
All share one Helm chart with per-service value overrides.

```
                        ┌─────────────────┐
                        │   api-gateway   │  Rollout · ON_DEMAND · canary
                        └────────┬────────┘
                                 │
          ┌──────────────────────┼──────────────────────┐
          ▼                      ▼                       ▼
  ┌──────────────┐    ┌──────────────────┐    ┌──────────────────┐
  │  customers   │    │     visits       │    │      vets        │
  │  Rollout     │    │     Rollout      │    │      Rollout     │
  │  SPOT · HPA  │    │     SPOT · HPA   │    │      SPOT · HPA  │
  └──────────────┘    └──────────────────┘    └──────────────────┘

  ┌──────────────┐    ┌──────────────────┐    ┌──────────────────┐
  │config-server │    │discovery-server  │    │  admin-server    │
  │ Deployment   │    │  Deployment      │    │  Deployment      │
  │ ON_DEMAND    │    │  ON_DEMAND       │    │  ON_DEMAND       │
  └──────────────┘    └──────────────────┘    └──────────────────┘

  ┌──────────────┐
  │ genai-service│  Rollout · SPOT · KEDA scale-to-zero when idle
  │ Scales to 0  │  Prometheus triggers: HTTP rate + CPU + memory
  └──────────────┘
          │
          ▼
  ┌──────────────────┐
  │  RDS MySQL 8.0   │  private subnet · KMS encrypted · Multi-AZ
  │                  │  Flyway migrations run as Helm pre-install hooks
  └──────────────────┘

ESO ExternalSecret pulls credentials from AWS Secrets Manager at pod startup. No database passwords in Git or Kubernetes manifests.
```

---

## HOW NODES AND PODS SCALE

Two levels of scaling — pods (software replicas) and nodes (EC2 VMs).

```
POD SCALING
  HPA                        KEDA                    Goldilocks + VPA
  ──────────────────         ──────────────────      ──────────────────
  Scales Deployments +       Scales genai-service    Watches running pods
  Rollouts on CPU +          to zero when idle.      and recommends right
  memory.                    Scales up on:           CPU/memory requests.
                             HTTP rate · CPU ·       Advisory only —
  customers · visits ·       memory metrics.         mode: Off.
  vets · api-gateway ·       Supports Argo           View in Goldilocks
  admin-server.              Rollout via             dashboard via VPN.
                             enableArgoproj.
                                    │
                                    ▼ pods need nodes

NODE SCALING — Karpenter
  Watches pending pods → provisions EC2 in ~30 seconds
  Consolidates underutilised nodes → terminates to reduce cost

  ON_DEMAND NodePool            SPOT NodePool
  ──────────────────────        ──────────────────────────────
  t4g (ARM64/Graviton)          t4g, m6g, m7g, c6g, c7g, r6g, r7g
  weight: 100                   weight: 1
  config-server                 customers, visits, vets, genai
  discovery-server              Toleration: spot=true:NoSchedule
  api-gateway                   SQS queue handles interruptions
  admin-server                  EventBridge → Karpenter drains
                                node before AWS reclaims it

  Bootstrap node group (1× t4g.medium)
  Terraform-managed · Karpenter only
  CriticalAddonsOnly taint — no application workloads
```

---

## WHAT PLATFORM ENGINEERS SEE

```
┌──────────────────────┐  ┌──────────────────────┐  ┌────────────────────────┐
│  METRICS             │  │  LOGS                │  │  ALERTS                │
│                      │  │                      │  │                        │
│  Prometheus          │  │  Alloy DaemonSet     │  │  30+ PrometheusRules   │
│  20Gi PVC · 15d      │  │  collects from:      │  │                        │
│                      │  │  petclinic           │  │  Alertmanager:         │
│  Scrapes:            │  │  monitoring          │  │  warning → Slack       │
│  • Spring Boot       │  │  istio-ingress       │  │  critical → Slack      │
│    Actuator          │  │                      │  │            + email     │
│  • Istio Envoy       │  │  Parses JSON         │  │                        │
│  • RDS via CW Exp.   │  │  Extracts level      │  │  Falco → Falcosidekick │
│  • Karpenter         │  │  Ships to Loki       │  │  → #petclinic-security │
│  • Velero            │  │                      │  │                        │
│  • ArgoCD            │  │  S3 backend · 31d    │  │  Velero failures       │
│  • Falco             │  │  LogQL via Grafana   │  │  → critical channel    │
│  • Trivy             │  │  Explore             │  │                        │
└──────────┬───────────┘  └──────────┬───────────┘  └───────────┬────────────┘
           └─────────────────────────┴─────────────────────────-─┘
                                     │
                                     ▼
                        ┌────────────────────────┐
                        │   Grafana (VPN only)   │
                        │                        │
                        │  7 dashboards:         │
                        │  • Cluster health      │
                        │  • Namespace/workload  │
                        │  • Per-service deep    │
                        │  • Istio / traffic     │
                        │  • ArgoCD / GitOps     │
                        │  • SLO / error budget  │
                        │  • RDS / database      │
                        └────────────────────────┘
```

---

## HOW THE PLATFORM ENFORCES RULES — 9 SECURITY LAYERS

Every deployment passes through nine independent layers automatically.

```
NETWORK LAYERS (L3/L4)
  Layer 1 — NetworkPolicy: default-deny-all on petclinic namespace
  Layer 2 — NetworkPolicy: explicit per-service allow rules

ADMISSION LAYERS
  Layer 3 — Kyverno ImageValidatingPolicy: Cosign signature verification
             Image must be signed by CI pipeline (keyless · GitHub OIDC)
             Vulnerability attestation must exist for the image

  Layer 4 — Kyverno ValidatingPolicy: pod security schema guardrails
             non-root · read-only root fs · drop ALL caps
             seccompProfile: RuntimeDefault required

  Layer 5 — Kyverno MutatingPolicy: automated security context defaults
             auto-injects missing security context fields

RUNTIME LAYERS
  Layer 6 — Istio PeerAuthentication: mTLS STRICT
             All pod-to-pod traffic encrypted and mutually authenticated
             Rejects any non-mTLS connection

  Layer 7 — External Secrets Operator: AWS Secrets Manager sync
             No secrets in Git · IRSA authenticates to AWS
             Secrets injected at pod startup only

  Layer 8 — Falco: eBPF runtime threat detection (modern_ebpf driver)
             Monitors syscalls on all nodes including SPOT
             Custom petclinic rules · alerts → Falcosidekick → Slack

  Layer 9 — Trivy Operator: continuous image scanning
             Every 24h · pod creation triggers immediate scan
             EKS CIS 1.4 + NSA hardening + PSS baseline every 6h
             .trivyignore mirrored between CI and Trivy Operator
```

**Supply chain (pre-admission):**
```
git push
  → Trivy scan (gate on CRITICAL)
  → ECR push (immutable tag)
  → Cosign sign (keyless · GitHub OIDC)
  → Cosign attest vulnerability report to ECR
  → Kyverno verifies signature + attestation at admission
  → pod starts

No unsigned or unattested image can run in the cluster.
```

---

## HOW DEPLOYMENTS HAPPEN

```
Branch policy (GitHub Actions):
  feature/* → dev   (PRs only · auto-closed if violated)
  dev       → main  (PRs only · auto-closed if violated)

Developer pushes → PR to dev → CI runs
        │
        ▼  GitHub Actions — matrix build, all 8 services in parallel

  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐  ┌──────────────────┐
  │ Build image   │  │  Trivy scan   │  │  Push to ECR  │  │  Cosign sign +   │
  │ Buildx        │→ │  Gate on      │→ │  Immutable    │→ │  attest vuln     │
  │ ARM64 + AMD64 │  │  CRITICAL     │  │  tag + latest │  │  report to ECR   │
  └───────────────┘  └───────────────┘  └───────────────┘  └──────────────────┘
        │
        ▼  values file updated with new image tag → commit to Git

ArgoCD polls Git every 2 minutes → detects image tag change
        │
        ▼  Kyverno admission: verify signature + attestation
        │
        ▼  Argo Rollouts canary:

  setWeight: 20%  →  pause 60s  →  AnalysisRun
    • success rate ≥ 99%
    • P99 latency ≤ 2s
    • error count ≤ 10

  setWeight: 40%  →  pause 60s  →  AnalysisRun

  setWeight: 80%  →  pause 120s  →  AnalysisRun

  setWeight: 100%  →  promote

  Any analysis failure → automatic rollback → stable restored

ArgoCD notifications → Slack #petclinic-gitops
  on-deployed · on-health-degraded · on-sync-failed
```

---

## SECRETS AND BACKUP

```
┌──────────────────────────────────────────┐  ┌──────────────────────────────────┐
│  SECRETS                                 │  │  BACKUP (Velero)                 │
│                                          │  │                                  │
│  No secrets in Git — ever.               │  │  Daily full cluster backup       │
│                                          │  │  30-day retention → S3           │
│  AWS Secrets Manager:                    │  │                                  │
│    prod/argocd           SSH deploy key  │  │  Hourly petclinic namespace      │
│    prod/petclinic         DB credentials │  │  7-day retention → S3            │
│    prod/platform-monitoring  Slack/email │  │                                  │
│    prod/platform-dns     Cloudflare token│  │  Daily monitoring namespace      │
│                                          │  │  Prometheus TSDB · Grafana PVC   │
│  IRSA: each component has its own IAM    │  │                                  │
│  role bound to its service account via   │  │  EBS snapshots for PVC data      │
│  EKS OIDC provider. No static creds.     │  │                                  │
│                                          │  │  node-agent DaemonSet tolerates  │
│  ESO ClusterSecretStore syncs secrets    │  │  SPOT — all nodes covered        │
│  into Kubernetes at pod startup.         │  │                                  │
└──────────────────────────────────────────┘  └──────────────────────────────────┘
```

**RDS Automated Backup:**
```
EventBridge (daily schedule)
    → Lambda (triggers RDS snapshot export)
    → RDS snapshot exported to S3 (KMS encrypted)
    → Lambda (Slack notification on failure)

Prod only — disabled in dev via count = local.is_prod ? 1 : 0
```

---

## DESIGN DECISIONS

**Karpenter over Cluster Autoscaler**
Direct EC2 provisioning via RunInstances — 30s node ready time versus
3-5 minutes for Cluster Autoscaler. Automatic consolidation reduces
cost without manual intervention. No predefined node groups required.

**Istio for traffic management**
Native Argo Rollouts integration via VirtualService weight management.
mTLS STRICT enforces encrypted communication without application changes.
Precise canary splitting regardless of replica count — 20% traffic does
not require 20% of pods to be canary.

**VPC Peering over Transit Gateway**
Two environments accessed by one engineer. VPC peering is the correct
tool at this scale. Transit Gateway would add cost and complexity
without operational benefit until a third environment or account is added.

**Single WireGuard server in prod VPC**
Simpler than a shared services VPC. One entry point for all cluster
access. VPC peering to dev means the server reaches both clusters.
Configured over SSM — no SSH port, no bastion host, no key management.

**Loki over Elasticsearch**
S3 backend eliminates large PVCs and index management. Sufficient for
structured log analysis at this scale. No JVM heap tuning or shard
management overhead.

**ESO over Sealed Secrets**
Secrets never exist in Git in any form. AWS Secrets Manager provides
rotation support, audit logging, and IAM-based access control. IRSA
eliminates static credentials from the cluster entirely.

**Policy-as-data**
Both NetworkPolicy and ArgoCD Applications use a map-based values
structure. Adding a service or application requires a values change
only — no template modifications. Mirrors how mature platform teams
manage policy at scale.