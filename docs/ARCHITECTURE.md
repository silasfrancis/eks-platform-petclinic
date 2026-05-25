# Architecture

## Overview

Kubernetes platform on AWS EKS built around the [Spring PetClinic](https://github.com/spring-petclinic/spring-petclinic-microservices) microservices application.

The platform runs two isolated environments:
- `dev`
- `prod`

Each environment has:
- its own VPC
- its own EKS cluster
- separate networking and database resources

A single WireGuard server in the production VPC provides VPN access to both environments through VPC peering. ArgoCD running in the production cluster also manages the development cluster remotely through the same peering connection.

![AWS Infrastructure](diagrams/aws-architecture.drawio.svg)

![EKS Platform Architecture](diagrams/eks-platform-architecture.drawio.svg)

---

# Network Architecture

## VPC Layout

```txt
Prod VPC — 10.0.0.0/16              Dev VPC — 10.1.0.0/16

┌─────────────────────────┐         ┌──────────────────────────┐
│                         │         │                          │
│ Public Subnets          │         │ Public Subnets           │
│ ├── WireGuard EC2       │         │ ├── External NLB         │
│ ├── External NLB        │         │ └── NAT Gateway          │
│ └── NAT Gateway         │         │                          │
│                         │◄──────► │ Private Subnets          │
│ Private Subnets         │ Peering │ ├── EKS worker nodes     │
│ ├── EKS worker nodes    │         │ └── Internal NLB         │
│ └── Internal NLB        │         │                          │
│                         │         │ Data Subnets             │
│ Data Subnets            │         │ └── RDS MySQL            │
│ └── RDS MySQL           │         │                          │
│                         │         └──────────────────────────┘
└─────────────────────────┘
```

---

## VPC Peering

A single VPC peering connection links the production and development VPCs.

The peering connection is used for:

1. VPN access from the WireGuard server to both clusters
2. ArgoCD multi-cluster management from prod to dev

```txt
Engineer Laptop
        │
        │ WireGuard VPN (UDP 51820)
        ▼
WireGuard EC2
(prod public subnet)
        │
        ├──────────────► Prod EKS API
        │
        └──► VPC Peering ─────► Dev EKS API


ArgoCD (prod cluster)
        │
        └──► VPC Peering ─────► Dev EKS cluster
```

The WireGuard client routes both VPC CIDRs through the tunnel:

```txt
AllowedIPs = 10.0.0.0/16, 10.1.0.0/16, 10.10.0.0/24
```

The development EKS API server allows inbound HTTPS traffic from the production VPC CIDR to support remote cluster management.

---

## Subnet Design

| Subnet Type | Resources |
|---|---|
| Public | WireGuard EC2, NAT Gateway, external NLB |
| Private | EKS nodes, internal NLB |
| Data | RDS MySQL |

Both environments use multi-AZ subnet layouts across two availability zones.

---

## WireGuard

WireGuard runs on a public EC2 instance in the production VPC with an Elastic IP.

The server is configured through Ansible over AWS SSM:
- no inbound SSH access
- no public Kubernetes endpoints
- internal tooling accessible only through VPN

The server acts as the single entry point for:
- engineers
- internal dashboards
- private cluster access

---

## DNS

| Record Type | Provider | Purpose |
|---|---|---|
| Public DNS | Cloudflare | Public application ingress |
| Private DNS | Route53 Private Hosted Zone | Internal dashboards and services |

ExternalDNS runs as separate deployments:
- Cloudflare controller for public records
- Route53 controller for private records

DNS records are created automatically from Kubernetes ingress resources.

---

# EKS Cluster

## Cluster Configuration

| Attribute | Value |
|---|---|
| Kubernetes Version | 1.35 |
| Architecture | ARM64 (Graviton) |
| Region | us-east-2 |
| Node Provisioning | Karpenter |
| CNI | AWS VPC CNI + Cilium |

---

## Node Pools

| Pool | Capacity Type | Workloads |
|---|---|---|
| Bootstrap | ON_DEMAND | Karpenter controller |
| ON_DEMAND | ON_DEMAND | config-server, discovery-server, api-gateway, admin-server |
| SPOT | SPOT | customers, visits, vets, genai |

SPOT interruption handling uses:
- EventBridge
- SQS interruption queue
- Karpenter node draining

---

# Traffic Flow

## Public Traffic

```txt
User
  ↓
Cloudflare DNS
  ↓
External NLB
  ↓
Istio Ingress Gateway
  ↓
VirtualService routing
  ↓
api-gateway
  ↓
Microservices
```

TLS certificates are managed through cert-manager using Let's Encrypt wildcard certificates.

---

## Internal Traffic

```txt
Engineer
  ↓
WireGuard VPN
  ↓
Private Route53 DNS
  ↓
Internal NLB
  ↓
Istio Internal Gateway
  ↓
Grafana / ArgoCD / Prometheus / Loki / Goldilocks
```

Internal dashboards are accessible only through the VPN.

---

## Service-to-Service Traffic

All inter-service communication flows through Istio sidecars with `STRICT` mTLS enabled cluster-wide.

AuthorizationPolicy resources restrict which workloads may communicate with each other.

Argo Rollouts controls VirtualService traffic weights during canary deployments.

---

# Application Layer

Eight Spring Boot services run in the `petclinic` namespace.

All services share:
- a single Helm chart
- per-service values files
- common deployment patterns

```txt
api-gateway
│
├── customers-service
├── visits-service
├── vets-service
├── genai-service
├── config-server
├── discovery-server
└── admin-server
        │
        ▼
RDS MySQL 8.0
```

Flyway migrations run as Helm hooks during deployment.

Database credentials are pulled dynamically from AWS Secrets Manager through External Secrets Operator and IRSA.

No application secrets are stored in Git.

---

# GitOps and Delivery

## Deployment Flow

```txt
git push
   │
   ▼
GitHub Actions
├── Build multi-arch images
├── Trivy vulnerability scan
├── Push image to ECR
├── Cosign signing
└── Cosign attestation
   │
   ▼
Commit updated image tag
   │
   ▼
ArgoCD sync
   │
   ▼
Kyverno admission validation
   │
   ▼
Argo Rollouts canary deployment
   │
   ├── 20%
   ├── analysis
   ├── 40%
   ├── analysis
   ├── 80%
   ├── analysis
   └── 100%
```

Failed rollout analysis triggers automatic rollback.

---

## ArgoCD Multi-Cluster

ArgoCD runs in the production cluster and manages:
- production applications locally
- development applications remotely through VPC peering

```txt
ArgoCD
├── prod applications
└── dev applications
```

The development cluster is registered as a remote cluster using its private API endpoint.

---

## Rollout Analysis

| Metric | Threshold |
|---|---|
| Success rate | >= 99% |
| P99 latency | <= 2s |
| Error count | <= 10 |

Any threshold breach triggers rollback.

---

# Security

## Security Layers

| Layer | Tool | Purpose |
|---|---|---|
| Network segmentation | Cilium NetworkPolicy | Default deny and service allow rules |
| Image verification | Kyverno | Cosign signature validation |
| Pod policy enforcement | Kyverno | Security schema validation |
| mTLS | Istio | Encrypted service communication |
| Secrets management | ESO + IRSA | Dynamic AWS secrets access |
| Runtime detection | Falco | eBPF runtime monitoring |
| Vulnerability scanning | Trivy Operator | Continuous image scanning |

---

## Supply Chain Security

```txt
GitHub Actions
    ↓
Trivy scan
    ↓
Push to ECR
    ↓
Cosign signing
    ↓
Cosign attestation
    ↓
Kyverno verification
    ↓
Deployment
```

Unsigned or unattested images are rejected at admission time.

---

## IRSA

AWS access is handled through IAM Roles for Service Accounts.

No static AWS credentials are stored inside workloads.

| Component | AWS Access |
|---|---|
| Loki | S3 |
| Velero | S3 + EBS snapshots |
| Karpenter | EC2 + SQS |
| External Secrets | Secrets Manager |
| ExternalDNS | Route53 |

---

# Observability

## Metrics

Prometheus collects metrics from:
- Spring Boot Actuator
- Istio sidecars
- Kubernetes workloads
- Karpenter
- Velero
- ArgoCD
- RDS exporters

---

## Logs

Alloy collects logs from cluster workloads and ships them to Loki with S3 object storage retention.

---

## Dashboards

| Dashboard | Purpose |
|---|---|
| Cluster Health | Node and workload health |
| Workloads | Namespace resource usage |
| Service Metrics | Request rate, errors, latency |
| Istio Traffic | Traffic flow and canary visibility |
| GitOps | ArgoCD sync and deployment state |
| Database | RDS metrics and performance |

All dashboards require VPN access.

---

## Alerts

| Severity | Destination |
|---|---|
| Warning | Slack |
| Critical | Slack + Email |
| Security | Falcosidekick → Slack |
| GitOps | ArgoCD Notifications |
| Backup Failures | Slack |

---

# Backup and Recovery

## Velero

| Scope | Schedule | Retention |
|---|---|---|
| Full cluster | Daily | 30 days |
| petclinic namespace | Hourly | 7 days |
| monitoring namespace | Daily | 7 days |

Backups are stored in S3.

PVC filesystem backups run through the Velero node-agent DaemonSet.

---

## RDS Backup Export

Production uses automated RDS snapshot exports to S3 triggered through:
- EventBridge
- Lambda

Snapshots are encrypted using KMS.

The export workflow is disabled in development.

---

# Cost Controls

| Resource | Dev | Prod |
|---|---|---|
| RDS | Single-AZ micro instance | Multi-AZ medium instance |
| NAT Gateway | Single NAT | NAT per AZ |
| RDS monitoring | Disabled | Enabled |
| Backup retention | 1 day | 7 days |
| Deletion protection | Disabled | Enabled |
| CloudWatch retention | 7 days | 30 days |
| Control plane logs | Disabled | Enabled |
| RDS export workflow | Disabled | Enabled |
| KMS deletion window | 7 days | 30 days |