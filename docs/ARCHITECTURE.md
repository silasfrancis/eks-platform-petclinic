# Architecture

## Overview

Kubernetes platform on AWS EKS built around the [Spring PetClinic](https://github.com/spring-petclinic/spring-petclinic-microservices) microservices application.

The platform combines multi-environment infrastructure, GitOps delivery,
service mesh networking, progressive delivery, autoscaling, observability,
runtime security, and disaster recovery into a single production-style
platform architecture.

<!-- Hero diagrams — visual overview -->
![AWS Infrastructure Architecture](diagrams/aws-architecture.drawio.svg)
*AWS infrastructure — VPC layout, EKS clusters, Transit Gateway, WireGuard VPN, IRSA, and RDS backup automation*

![EKS Platform Architecture](diagrams/eks-platform-architecture.drawio.svg)
*Platform layers — supply chain, GitOps, service mesh, observability, autoscaling, and security enforcement*

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

Two environments run as fully independent EKS clusters in separate VPCs.

Each environment:
- has its own VPC
- runs its own ArgoCD instance
- manages only its own applications
- remains isolated from the other environment

A dedicated WireGuard VPC provides secure administrative access to both
clusters through an AWS Transit Gateway.

```txt
WireGuard VPC — 10.2.0.0/16
┌──────────────────────┐
│  Public subnet       │
│  ├── WireGuard EC2   │
│  └── Elastic IP      │
└──────────┬───────────┘
           │
    ┌──────▼──────┐
    │  Transit    │
    │  Gateway    │
    └──┬──────┬───┘
       │      │
┌──────▼──┐  ┌▼──────────┐
│Dev VPC  │  │Prod VPC   │
│10.1.0.0 │  │10.0.0.0   │
│  /16    │  │  /16      │
│         │  │           │
│Public   │  │Public     │
│subnets: │  │subnets:   │
│Ext. NLB │  │Ext. NLB   │
│NAT GW   │  │NAT GW     │
│         │  │           │
│Private  │  │Private    │
│subnets: │  │subnets:   │
│EKS nodes│  │EKS nodes  │
│Int. NLB │  │Int. NLB   │
│         │  │           │
│Data:    │  │Data:      │
│RDS      │  │RDS        │
│         │  │           │
│ArgoCD   │  │ArgoCD     │
│(dev)    │  │(prod)     │
└─────────┘  └───────────┘
```

### Transit Gateway

A single AWS Transit Gateway connects all three VPCs using explicit
route table associations and propagations.

Default TGW route table association and propagation are disabled so
all routing remains intentionally defined.

### Isolation Model

| From | To | Result |
|---|---|---|
| WireGuard | Dev | Allowed |
| WireGuard | Prod | Allowed |
| Dev | WireGuard | Allowed |
| Prod | WireGuard | Allowed |
| Dev | Prod | Blocked (explicit black-hole route) |
| Prod | Dev | Blocked (explicit black-hole route) |

### Administrative Access Flow

```txt
Engineer laptop
    │ WireGuard VPN UDP 51820
    ▼
WireGuard EC2
(WireGuard VPC · public subnet · Elastic IP)
    │
    │ Transit Gateway
    ├──────────────────────► Prod EKS API
    │
    └──────────────────────► Dev EKS API

Client AllowedIPs = 10.0.0.0/8
```

### TGW Route Tables

Each VPC attachment is associated with its own TGW route table.

| Route Table | Allowed Routes |
|---|---|
| WireGuard | WireGuard + Dev + Prod |
| Dev | Dev + WireGuard |
| Prod | Prod + WireGuard |

Explicit black-hole routes enforce dev ↔ prod isolation even if future
propagation rules are modified accidentally.

### ArgoCD Per Environment

Each EKS cluster runs its own ArgoCD instance.

```txt
ArgoCD (dev cluster)   → manages dev applications only
ArgoCD (prod cluster)  → manages prod applications only
```

There is no cross-cluster GitOps control plane.

This reduces blast radius:
- an ArgoCD outage in one environment cannot affect the other
- sync failures remain isolated
- RBAC boundaries stay environment-specific
- clusters remain operationally self-contained

---

## HOW USERS AND ENGINEERS ACCESS THE PLATFORM

Public application traffic and internal administrative traffic use
completely separate ingress paths.

```txt
┌──────────────────────────────────────────┐  ┌────────────────────────────────────┐
│  PUBLIC TRAFFIC                          │  │  INTERNAL / ADMIN TRAFFIC          │
│                                          │  │                                    │
│  Anyone on the internet                  │  │  Engineers only (VPN required)     │
│          │                               │  │          │                         │
│          ▼                               │  │          ▼                         │
│  Cloudflare DNS                          │  │  WireGuard VPN                     │
│  public A record → External NLB          │  │  Dedicated WireGuard VPC           │
│          │                               │  │  Configured via Ansible over SSM   │
│          ▼                               │  │  No SSH port open                  │
│  External NLB                            │  │          │                         │
│  internet-facing · port 443              │  │          ▼                         │
│          │                               │  │  Transit Gateway                   │
│          ▼                               │  │  Routes to prod or dev VPC         │
│  Istio PUBLIC Gateway                    │  │          │                         │
│  TLS termination                         │  │          ▼                         │
│  wildcard certificate                    │  │  Route53 Private Hosted Zone       │
│  cert-manager DNS-01                     │  │  Internal DNS only                 │
│          │                               │  │          │                         │
│          ▼                               │  │          ▼                         │
│  petclinic.lefrancis.org                 │  │  Internal NLB                      │
│  Spring PetClinic services               │  │  Private subnet only               │
│                                          │  │          │                         │
│                                          │  │          ▼                         │
│                                          │  │  Istio INTERNAL Gateway            │
│                                          │  │  TLS termination                   │
│                                          │  │          │                         │
│                                          │  │          ▼                         │
│                                          │  │  grafana.lefrancis.org             │
│                                          │  │  argocd.lefrancis.org              │
│                                          │  │  prometheus.lefrancis.org          │
│                                          │  │  loki.lefrancis.org                │
└──────────────────────────────────────────┘  └────────────────────────────────────┘
              │                                                  │
              └──────────────► cert-manager ◄────────────────────┘
                               Let's Encrypt DNS-01
                               Cloudflare API token via ESO
```

### DNS Automation

```txt
ExternalDNS (Cloudflare)
  → public DNS records
  → petclinic.lefrancis.org

ExternalDNS (Route53)
  → private DNS records
  → Grafana, ArgoCD, Prometheus, Loki, Goldilocks
```

Two independent ExternalDNS deployments are used:
- public DNS automation for internet-facing services
- private Route53 automation for VPN-only services

---

## HOW TRAFFIC ROUTES INSIDE THE CLUSTER

Every pod receives an automatically injected Istio Envoy sidecar.

All inter-service traffic flows through the service mesh, allowing:
- mTLS encryption
- traffic routing
- canary delivery
- policy enforcement
- telemetry collection

without modifying application code.

```txt
Request arrives at Istio Gateway
        │
        ▼
VirtualService routes by path:

  /api/customer/*  → customers-service
  /api/visit/*     → visits-service
  /api/vet/*       → vets-service
  /api/genai/*     → genai-service
  /*               → api-gateway

Canary release flow:

  80% → stable
  20% → canary

          stable-svc
               │
        DestinationRule
               │
          canary-svc
```

Argo Rollouts manages Istio VirtualService weights during progressive
delivery.

ArgoCD ignores temporary weight drift while a rollout is active to
prevent reconciliation conflicts.

### Service-to-Service Security

All pod-to-pod traffic uses:

```txt
PeerAuthentication: STRICT
AuthorizationPolicy: service-account identity based
```

Traffic is authenticated using Istio-issued workload certificates rather
than IP-based rules.

---

## THE APPLICATION

Eight Spring Boot microservices are deployed into the `petclinic`
namespace using a shared Helm chart with per-service overrides.

```txt
                        ┌─────────────────┐
                        │   api-gateway   │
                        │ Rollout · Canary│
                        └────────┬────────┘
                                 │
          ┌──────────────────────┼──────────────────────┐
          ▼                      ▼                       ▼

  ┌──────────────┐    ┌──────────────────┐    ┌──────────────────┐
  │ customers    │    │ visits           │    │ vets             │
  │ Rollout      │    │ Rollout          │    │ Rollout          │
  │ SPOT · HPA   │    │ SPOT · HPA       │    │ SPOT · HPA       │
  └──────────────┘    └──────────────────┘    └──────────────────┘

  ┌──────────────┐    ┌──────────────────┐    ┌──────────────────┐
  │ config-server│    │ discovery-server │    │ admin-server     │
  │ Deployment   │    │ Deployment       │    │ Deployment        │
  │ ON_DEMAND    │    │ ON_DEMAND        │    │ ON_DEMAND         │
  └──────────────┘    └──────────────────┘    └──────────────────┘

  ┌──────────────┐
  │ genai-service│
  │ Rollout      │
  │ KEDA         │
  │ Scale-to-zero│
  └──────────────┘
          │
          ▼
  ┌──────────────────┐
  │ RDS MySQL 8.0    │
  │ Multi-AZ         │
  │ KMS encrypted    │
  └──────────────────┘
```

Database credentials are synchronised into the cluster through:
- AWS Secrets Manager
- External Secrets Operator
- IRSA authentication

No database credentials exist in Git or Helm values files.

---

## HOW NODES AND PODS SCALE

The platform scales at two levels:

1. Pods
2. Nodes

```txt
POD SCALING
────────────────────────────────────────────────────

HPA
  CPU + memory autoscaling

KEDA
  Scale-to-zero event-driven scaling
  Used by genai-service

Goldilocks + VPA
  Resource recommendations only

────────────────────────────────────────────────────
               Pods require nodes
────────────────────────────────────────────────────

NODE SCALING — Karpenter

ON_DEMAND NodePool
  ARM64 Graviton
  Critical workloads

SPOT NodePool
  Mixed-instance ARM64 fleet
  Cost-optimised workloads
```

### Karpenter

Karpenter provisions EC2 instances directly through the EC2 API.

Benefits:
- ~30 second node startup
- no pre-created node groups
- automatic consolidation
- mixed instance scheduling
- native Spot interruption handling

### Spot Handling

Spot interruption flow:

```txt
EventBridge
    → SQS
    → Karpenter interruption controller
    → drain node
    → reschedule pods
```

---

## WHAT PLATFORM ENGINEERS SEE

```txt
┌──────────────────────┐  ┌──────────────────────┐  ┌────────────────────────┐
│  METRICS             │  │  LOGS                │  │  ALERTS                │
│                      │  │                      │  │                        │
│  Prometheus          │  │  Alloy DaemonSet     │  │  Alertmanager          │
│  Spring metrics      │  │  Parses JSON logs    │  │  Slack + email         │
│  Istio metrics       │  │  Ships to Loki       │  │                        │
│  Karpenter metrics   │  │  S3 retention        │  │  Falco alerts          │
│  Velero metrics      │  │                      │  │  Velero failures       │
│  ArgoCD metrics      │  │                      │  │  Deployment alerts     │
└──────────┬───────────┘  └──────────┬───────────┘  └───────────┬────────────┘
           └─────────────────────────┴──────────────────────────┘
                                     │
                                     ▼
                        ┌────────────────────────┐
                        │ Grafana (VPN only)     │
                        │                        │
                        │ Cluster dashboards     │
                        │ Service dashboards     │
                        │ Istio dashboards       │
                        │ GitOps dashboards      │
                        │ SLO dashboards         │
                        └────────────────────────┘
```

---

## HOW THE PLATFORM ENFORCES RULES — 9 SECURITY LAYERS

Every workload passes through nine independent security layers.

```txt
NETWORK LAYERS
────────────────────────────────────────

1. Cilium NetworkPolicy
   Default deny-all

2. Cilium NetworkPolicy
   Explicit service allow rules

ADMISSION LAYERS
────────────────────────────────────────

3. Kyverno ImageValidatingPolicy
   Cosign signature verification
   Vulnerability attestation verification

4. Kyverno ValidatingPolicy
   Pod security enforcement

5. Kyverno MutatingPolicy
   Automatic security context injection

RUNTIME LAYERS
────────────────────────────────────────

6. Istio PeerAuthentication
   STRICT mTLS

7. External Secrets Operator
   Secrets Manager integration via IRSA

8. Falco
   Runtime syscall monitoring via eBPF

9. Trivy Operator
   Continuous vulnerability scanning
```

### Supply Chain Enforcement

```txt
git push
  → Trivy scan
  → ECR push
  → Cosign sign
  → Cosign attest
  → ArgoCD sync
  → Kyverno verification
  → pod starts
```

Unsigned or unattested images are rejected at admission.

---

## HOW DEPLOYMENTS HAPPEN

```txt
feature/* → dev
dev       → main

Developer push
        │
        ▼
GitHub Actions CI

  Build multi-arch image
        │
        ▼
  Trivy vulnerability scan
        │
        ▼
  Push immutable image to ECR
        │
        ▼
  Cosign sign image
        │
        ▼
  Cosign attach attestation
        │
        ▼
  Update Helm values
        │
        ▼
  ArgoCD reconciliation
        │
        ▼
  Argo Rollouts canary deployment
```

### Canary Analysis

```txt
20% traffic → AnalysisRun
50% traffic → AnalysisRun
100% promote
```

Rollback occurs automatically if:
- success rate drops
- latency exceeds threshold
- error rate increases

---

## SECRETS AND BACKUP

```txt
SECRETS
────────────────────────────────────────

AWS Secrets Manager
  → database credentials
  → Cloudflare tokens
  → Slack webhooks
  → ArgoCD deploy keys

External Secrets Operator
  → synchronises secrets into Kubernetes

IRSA
  → per-service AWS authentication

────────────────────────────────────────

BACKUP
────────────────────────────────────────

Velero
  → daily cluster backups
  → namespace backups
  → EBS snapshots

RDS snapshot export
  → EventBridge
  → Lambda
  → encrypted S3 storage
```

No secrets are stored in Git.

---

## DESIGN DECISIONS

### Karpenter over Cluster Autoscaler

Karpenter provisions EC2 instances directly rather than scaling managed
node groups.

Benefits:
- faster provisioning
- mixed-instance flexibility
- automated consolidation
- simpler scaling model

### Istio for Traffic Management

Istio integrates natively with Argo Rollouts through VirtualService
weight management.

Benefits:
- precise canary traffic splitting
- automatic mTLS
- workload identity
- traffic observability

### Transit Gateway over VPC Peering

Three VPCs require a hub-and-spoke routing model.

Transit Gateway provides:
- transitive routing
- centralised routing policy
- scalable attachment model
- explicit route-table isolation
- simpler future expansion

### Dedicated WireGuard VPC

WireGuard runs in its own isolated VPC with no workloads.

Benefits:
- reduced blast radius
- isolated VPN entry point
- cleaner routing boundaries
- simplified network model

### Separate ArgoCD per Environment

Each environment manages itself independently.

Benefits:
- isolated failure domains
- reduced operational risk
- environment-specific RBAC
- independent reconciliation

### Loki over Elasticsearch

Loki stores logs in S3 without requiring Elasticsearch index management.

Benefits:
- lower operational overhead
- no JVM tuning
- smaller infrastructure footprint
- cost-efficient retention

### External Secrets Operator over Sealed Secrets

Secrets never exist in Git.

Benefits:
- IAM-based access control
- native AWS audit logging
- secret rotation support
- no encrypted secret manifests

### Policy-as-Data

Policies are driven through structured values maps rather than hardcoded
templates.

Benefits:
- scalable service onboarding
- reusable policy logic
- simplified maintenance
- reduced template duplication