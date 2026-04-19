# Architecture

## System Overview

```
Git Repository (single source of truth)
          │
          ▼
      ArgoCD (App of Apps)
          │
    ┌─────┴──────────────┐
    │                    │
Platform Layer       Application Layer
    │                    │
    ├── Compute          └── 8 PetClinic Microservices
    ├── Ingress
    ├── Monitoring
    ├── Autoscaling
    ├── Backup
    │
    └── Security
         ├── Kyverno (policies)
         └── NetworkPolicies
```

See [architecture.png](diagrams/architecture.png) for the full AWS diagram.

## Infrastructure

### VPC Layout

```
VPC — us-east-2 (10.0.0.0/16)
│
├── Public Subnets (2 AZs)
│   ├── Internet Gateway
│   ├── NAT Gateway
│   ├── Internet-facing NLB (petclinic.lefrancis.org)
│   └── WireGuard EC2 (Elastic IP)
│
├── Private Subnets (2 AZs)
│   ├── EKS Worker Nodes (Karpenter)
│   └── Internal NLB (dashboards — VPN only)
│
└── Data Subnets (2 AZs)
    └── RDS MySQL (Multi-AZ)
```

### EKS Node Architecture

Karpenter manages two NodePools:

| NodePool | Instance Types | Capacity | Workloads |
|---|---|---|---|
| on-demand | t4g.medium/large | Guaranteed | Config server, Discovery server, API gateway, Admin server |
| spot | t4g/m6g/c6g/r6g | Interruptible | Customers, Visits, Vets, GenAI services |

A bootstrap node group (1× t4g.medium, Terraform-managed) runs Karpenter only.
Application workloads never land on the bootstrap group.

All nodes run AL2023 ARM64 (Graviton). Images are built for `linux/arm64`
via Docker Buildx with `BUILDPLATFORM`/`TARGETPLATFORM` args.

### WireGuard Server

A private EC2 instance (t4g.nano) acts as the VPN gateway for internal
dashboard access. It is configured via Ansible over AWS SSM — no SSH port
is open. This is provisioned and configured before any platform bootstrap
steps, as ArgoCD and all internal dashboards sit behind it.

```
Ansible → AWS SSM → WireGuard EC2 (public subnet, Elastic IP)
                          │
                    WireGuard tunnel (UDP 51820)
                          │
              VPN client (engineer's laptop)
                          │
              Route53 Private Hosted Zone (DNS resolution)
                          │
              Internal NLB (private subnets)
                          │
        Grafana / ArgoCD / Prometheus / Loki
```

## Application Architecture

### Microservices

Eight Spring Boot services communicate internally via the Istio service mesh:

```
                   ┌──────────────────┐
External traffic   │  Istio Gateway   │  petclinic.lefrancis.org
──────────────────▶│  (Public NLB)    │
                   └────────┬─────────┘
                            │
                   ┌────────▼─────────┐
                   │   API Gateway    │  :8080
                   └──┬──┬──┬──┬─────┘
                      │  │  │  │
          ┌───────────┘  │  │  └──────────────┐
          │              │  │                  │
  ┌───────▼──────┐ ┌─────▼──┴──────┐ ┌────────▼───────┐
  │  Customers   │ │    Visits     │ │     Vets       │
  │  :8081       │ │    :8082      │ │     :8083      │
  └──────┬───────┘ └──────┬────────┘ └───────┬────────┘
         └────────────────┼───────────────────┘
                          │
                  ┌───────▼───────┐
                  │  RDS MySQL    │
                  └───────────────┘

All services → Config Server (:8888) at startup
All services → Discovery Server (:8761) for Eureka registration
API Gateway  → GenAI Service (:8084) for AI features
```

### Canary Deployment Flow

```
CI pushes new image to ECR
          │
          ▼
ArgoCD detects image change → triggers sync
          │
          ▼
Argo Rollouts starts canary
          │
    setWeight: 20%
          │
    pause: 60s
          │
    AnalysisRun → queries Prometheus
      ├── success rate >= 99%     ✓ continue
      ├── P99 latency <= 2s       ✓ continue
      └── error count <= 10       ✓ continue
          │
    setWeight: 50% → pause → analysis
          │
    setWeight: 100% → promote
          │
    ✗ any metric fails → auto-rollback to stable
```

Istio VirtualService weights are managed by Argo Rollouts during the canary.
ArgoCD is configured to ignore VirtualService weight diffs to prevent
sync conflicts.

## GitOps Architecture

### App of Apps

```
root-app.yaml (applied once manually via task deploy_root_app)
          │
          ▼
ArgoCD watches k8s/argocd/apps/
          │
          ├── Wave 0  argocd          (self-managed, prune: false)
          ├── Wave 1  policies        (Kyverno — must exist before workloads)
          ├── Wave 1  compute         (Karpenter — nodes before workloads)
          ├── Wave 1  ingress         (Istio gateway + DNS + certs)
          ├── Wave 1  monitoring      (Prometheus + Grafana + Loki)
          ├── Wave 2  security        (Trivy + Falco)
          ├── Wave 2  autoscaling     (KEDA + Goldilocks)
          ├── Wave 2  backup          (Velero)
          └── Wave 3  microservices   (one Application per service)
```

### Per-Service Applications

Each microservice is an independent ArgoCD Application pointing to the
same shared Helm chart with a per-service values override:

```
ArgoCD Application: customers-service
  source:
    path: k8s/apps/microservice          (shared chart)
    helm.valueFiles:
      - values.yaml                      (common defaults)
      - values/env/dev/customers-service.yaml  (service overrides)
```

This means deploying one service does not affect others, and each service
can be synced, rolled back, or paused independently.

### ArgoCD Notifications

ArgoCD sends deployment events to Slack via the notifications controller.
The CI pipeline does not trigger ArgoCD — ArgoCD polls Git and syncs
automatically. Notifications inform the team when:

- An application syncs and becomes healthy (on-deployed)
- An application health degrades (on-health-degraded)
- A sync operation fails (on-sync-failed)

## Networking Architecture

### Dual Gateway Setup

Two Istio ingress gateways handle different traffic:

```
Public gateway  (internet-facing NLB)
  Hosts:   petclinic.lefrancis.org
  DNS:     Cloudflare (public records)
  Access:  Anyone on the internet

Internal gateway  (private NLB)
  Hosts:   grafana / argocd / prometheus / loki .lefrancis.org
  DNS:     Route53 private hosted zone (VPC-only resolution)
  Access:  WireGuard VPN clients only
```

### ExternalDNS Split

Two ExternalDNS instances run independently:

| Instance | Provider | Annotation filter | Zone type |
|---|---|---|---|
| external-dns-cloudflare | Cloudflare | provider=cloudflare | public |
| external-dns-route53 | AWS Route53 | provider=route53 | private |

Each instance only manages records for resources with its matching
provider annotation, preventing cross-contamination.

### Network Policy Model

Default-deny-all is applied to the petclinic namespace.
Explicit allow rules are generated from the `clusterPolicy.services` map
in `k8s/policies/values.yaml` — adding a service requires one values entry,
no template changes.

```
Allowed traffic paths:
  Istio Gateway → API Gateway
  API Gateway   → Customers, Visits, Vets, GenAI
  All services  → Config Server   (startup config pull)
  All services  → Discovery Server (Eureka registration)
  Customers, Visits, Vets → RDS MySQL (:3306)
  Prometheus    → All services (/actuator/prometheus)
  Istio control plane ↔ all sidecars
```

### Three-Layer Pod-to-Pod Security

```
Request: api-gateway → customers-service

Layer 1  Cilium NetworkPolicy
         "Is the source pod allowed to connect on this port?"
         Blocks at TCP level before any data is sent.

Layer 2  Istio PeerAuthentication (mTLS STRICT)
         "Are both pods presenting valid mesh certificates?"
         Rejects any non-mTLS connection.

Layer 3  Istio AuthorizationPolicy
         "Is the source service account authorised to call this path?"
         Returns HTTP 403 if not explicitly allowed.

All three must pass for the request to reach the destination container.
```

## Observability Architecture

### Metrics

```
Spring Boot Actuator (/actuator/prometheus)
Istio Envoy sidecar (/stats/prometheus)
AWS RDS via CloudWatch Exporter
          │
          ▼ ServiceMonitor / PodMonitor
     Prometheus (20Gi PVC, 15 day retention)
          │
          ▼
       Grafana (7 dashboards)
         ├── Cluster Health
         ├── Namespace / Workload Overview
         ├── Per-Service Deep Dive
         ├── Istio / Traffic
         ├── ArgoCD / GitOps
         ├── SLO / Error Budget
         └── RDS / Database
```

### Logs

```
Pod stdout/stderr
          │
          ▼ Alloy DaemonSet (HCL pipeline)
          │   ├── filter: petclinic, monitoring, istio-ingress namespaces
          │   └── parse: JSON structured logs, extract level label
          ▼
       Loki (SingleBinary, S3 backend, 31 day retention)
          │
          ▼
       Grafana Explore (LogQL queries)
```

### Alerts

```
PrometheusRules (30+ rules)
          │
          ▼
     Alertmanager
          │
    ┌─────┴──────┐
    │            │
 warning       critical
    │            │
 Slack          Slack + Email
 #petclinic-    #petclinic-
 warnings       critical

Falco events → Falcosidekick → Slack #petclinic-security
Velero backup failures → Prometheus → Alertmanager → critical path
```

## Design Decisions

### Karpenter over Cluster Autoscaler
Direct EC2 provisioning — 30-60s node ready time versus 3-5 minutes for
Cluster Autoscaler. No predefined node groups needed. Karpenter consolidates
underutilised nodes automatically, reducing cluster cost.

### Istio for Traffic Management
Native Argo Rollouts integration via VirtualService weight management.
mTLS STRICT enforces encrypted communication without application changes.
Precise canary traffic splitting regardless of replica count — 10% traffic
to canary does not require 10% of pods to be canary.

### Loki over Elasticsearch
S3 backend eliminates large persistent volumes and index management overhead.
Sufficient query capability for structured log analysis at this scale.
Lower operational complexity — no JVM heap tuning or shard management.

### ESO over Sealed Secrets
Secrets never exist in Git in any form. AWS Secrets Manager provides
automatic rotation support, audit logging, and access control via IAM.
IRSA authentication eliminates static credentials from the cluster entirely.

### Policy-as-Data Pattern
Both `clusterPolicy` (NetworkPolicy + Kyverno) and `argocdBootstrap`
(ArgoCD Applications) use a map-based values structure where templates
loop over data. Adding a service or application requires a values change
only — no template modifications. This mirrors how mature platform teams
manage policy at scale.