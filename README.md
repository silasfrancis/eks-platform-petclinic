# PetClinic Platform

Production-style Kubernetes platform on AWS EKS built around the Spring PetClinic microservices application.

The repository combines infrastructure provisioning, GitOps delivery, cluster networking, autoscaling, observability, runtime security, and operational tooling across isolated production and development environments.

Production and development environments are isolated at the Transit Gateway routing layer while remaining accessible through a dedicated WireGuard VPN VPC.

![Architecture](docs/diagrams/aws-architecture.drawio.svg)

---

## Table of Contents

- [Platform Components](#platform-components)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Infrastructure Provisioning](#infrastructure-provisioning)
  - [Bootstrap Terraform State](#1-bootstrap-terraform-state)
  - [Provision Shared Application Registry Resources](#2-provision-shared-application-registry-resources)
  - [Provision Environment Infrastructure](#3-provision-environment-infrastructure)
  - [Provision WireGuard Infrastructure](#4-provision-wireguard-infrastructure)
  - [Provision Transit Gateway Networking](#5-provision-transit-gateway-networking)
- [WireGuard Setup](#wireguard-setup)
- [Configure kubectl](#configure-kubectl)
- [Configure Platform Domains](#configure-platform-domains)
- [Bootstrap the Cluster](#bootstrap-the-cluster)
- [Verification](#verification)
- [Internal Services](#internal-services)
- [Documentation](#documentation)
- [Stack Overview](#stack-overview)

---

## Platform Components

| Area | Implementation |
|---|---|
| Kubernetes | AWS EKS on Graviton (ARM64) |
| Networking | AWS VPC CNI + Cilium (CNI chaining mode) |
| Service Mesh | Istio with mTLS and traffic routing |
| Ingress | Istio Gateway + ExternalDNS + cert-manager |
| Node Scaling | Karpenter |
| Pod Scaling | HPA + KEDA |
| GitOps | ArgoCD (App of Apps, one instance per environment) |
| Progressive Delivery | Argo Rollouts |
| Policy Enforcement | Kyverno |
| Runtime Security | Falco + Trivy Operator |
| Secrets Management | AWS Secrets Manager + External Secrets Operator |
| Observability | Prometheus, Grafana, Loki, Alloy |
| Backup & Recovery | Velero |
| CI/CD Security | Trivy image scanning + Cosign signing |

---

## Repository Structure

```txt
.
├── terraform/         # AWS infrastructure and shared resources
├── k8s/               # Kubernetes platform and GitOps resources
│   ├── platform/      # Istio, monitoring, autoscaling, security, backups
│   ├── argocd/        # App of Apps configuration
│   ├── bootstrap/     # Cluster bootstrap components
│   └── microservice/  # Shared Helm chart for all microservices
├── services/          # Spring Boot microservices
├── ansible/           # WireGuard automation via SSM
├── migrations/        # Database migrations
├── docs/              # Documentation and architecture diagrams
└── scripts/           # Validation and helper scripts
```

---

## Prerequisites

| Tool | Version |
|---|---|
| AWS CLI | >= 2.x |
| kubectl | >= 1.29 |
| Helm | >= 3.14 |
| Terraform | >= 1.7 |
| Ansible | >= 2.15 |
| Task | >= 3.x |
| ArgoCD CLI | >= 2.10 |
| Docker | >= 25.x |
| Java | >= 17 |
| Maven | >= 3.9 |

---

## Infrastructure Provisioning

Infrastructure is split into five layers:

1. Terraform backend state
2. Shared application registry resources
3. Environment infrastructure
4. WireGuard infrastructure
5. Transit Gateway networking

---

### 1. Bootstrap Terraform State

Creates the S3 backend infrastructure used by Terraform state.

> [!NOTE]
> The bootstrap stack creates the remote Terraform backend itself.
> Review the task summary before running for the first time.

```bash
task tf:bootstrap --summary
task tf:bootstrap
```

---

### 2. Provision Shared Application Registry Resources

Shared metadata resources provisioned once and reused across environments.

This layer currently manages:

- AWS Service Catalog AppRegistry metadata
- shared resource metadata tagging

```bash
# Initialise backend
task tf:app-registry:init

# Validate configuration
task tf:app-registry:validate

# Review planned changes
task tf:app-registry:plan

# Provision shared resources
task tf:app-registry:apply
```

---

### 3. Provision Environment Infrastructure

Provisions environment-specific AWS infrastructure.

Includes:

- VPC networking
- EKS cluster
- IAM and IRSA
- RDS
- platform infrastructure

```bash
# Initialise backend
task tf:init ENV=dev

# Validate configuration
task tf:validate ENV=dev

# Review infrastructure changes
task tf:plan ENV=dev

# Provision infrastructure
task tf:apply ENV=dev
```

Run once per environment.

---

### 4. Provision WireGuard Infrastructure

Provision the dedicated WireGuard VPN VPC and EC2 instance.

This layer is independent and may be provisioned before or after environment infrastructure.

```bash
# Initialise backend
task tf:wireguard:init

# Validate configuration
task tf:wireguard:validate

# Review planned changes
task tf:wireguard:plan

# Provision WireGuard infrastructure
task tf:wireguard:apply
```

---

### 5. Provision Transit Gateway Networking

Provision shared Transit Gateway networking connecting all VPCs.

This layer should be applied after all environment and WireGuard VPCs exist.

Includes:

- AWS Transit Gateway
- TGW VPC attachments
- TGW route tables
- explicit dev ↔ prod isolation black-hole routes
- RFC1918 routing

```bash
# Initialise backend
task tf:transit-gateway:init

# Validate configuration
task tf:transit-gateway:validate

# Review planned changes
task tf:transit-gateway:plan

# Provision Transit Gateway networking
task tf:transit-gateway:apply
```

---

## WireGuard Setup

WireGuard runs on a public EC2 instance inside a dedicated WireGuard VPC and is configured through Ansible over AWS Systems Manager Session Manager (SSM).

The VPN server connects to all environments through the Transit Gateway, acting as the single secure entry point for:

- direct access to the production cluster
- direct access to the development cluster
- isolated routing — dev and prod cannot reach each other

```bash
# Install Ansible dependencies
task ansible:setup

# Verify SSM connectivity
task ansible:ping

# Configure WireGuard
task ansible:configure_wireguard

# Verify tunnel status
task ansible:check_wireguard
```

### Prerequisites

- WireGuard and Transit Gateway infrastructure provisioned
- WireGuard EC2 instance running
- AWS credentials configured locally
- `inventory.yaml` populated with the EC2 instance ID

### After Setup

1. Retrieve the generated client configuration from the server
2. Import it into the WireGuard client application
3. Connect to the VPN before accessing internal services

Once connected, the VPN routes traffic to both environments through the Transit Gateway:

- production workloads via the prod VPC attachment
- development workloads via the dev VPC attachment

Dev and prod environments cannot reach each other — isolation is enforced at the TGW route table level.

SSH access is not exposed on the WireGuard server.
All administration occurs through AWS Systems Manager Session Manager.

---

## Configure kubectl

```bash
aws eks update-kubeconfig \
  --region us-east-2 \
  --name <cluster-name> \
  --role-arn arn:aws:iam::<account-id>:role/EKSAdminRole
```

The IAM role above is granted EKS access through Terraform-managed access entries.

---

## Configure Platform Domains

The repository uses `lefrancis.org` as the example domain.

Before deployment, update all platform ingress hostnames to match your own domain and DNS zones.

### Platform Ingress Gateway

Update the shared ingress gateway configuration:

```bash
k8s/platform/ingress/values/env/<env>/values.yaml
```

Example:

```yaml
petclinic:
  host: petclinic.example.com
```

### ArgoCD

Update the ArgoCD ingress hostname:

```bash
k8s/argocd/values/env/<env>/values.yaml
```

Example:

```yaml
server:
  ingress:
    host: argocd.example.com
```

### Monitoring Stack

Update monitoring ingress hostnames:

```bash
k8s/platform/monitoring/values/env/<env>/values.yaml
```

Examples:

```yaml
grafana:
  ingress:
    host: grafana.example.com

prometheus:
  ingress:
    host: prometheus.example.com

loki:
  ingress:
    host: loki.example.com
```

### Autoscaling Stack

Update Goldilocks ingress hostname:

```bash
k8s/platform/autoscaling/values/env/<env>/values.yaml
```

Example:

```yaml
goldilocks:
  ingress:
    host: goldilocks.example.com
```

Also ensure:

- your DNS provider credentials are configured
- Cloudflare or Route53 zones exist
- the domain points to the platform load balancers

---

## Bootstrap the Cluster

```bash
# Validate all Helm charts
task validate ENV=dev

# Install base platform components
task k8s:bootstrap ENV=dev CLUSTER_NAME=<cluster-name>

# Deploy platform services and workloads
task k8s:deploy-all ENV=dev
```

---

## Verification

```bash
# Verify worker nodes
kubectl get nodes

# Verify platform workloads
kubectl get pods -A

# Verify PetClinic workloads
kubectl get pods -n petclinic
```

---

## Internal Services

| Service | Access |
|---|---|
| Petclinic | Public |
| ArgoCD | WireGuard VPN |
| Grafana | WireGuard VPN |
| Prometheus | WireGuard VPN |
| Loki | WireGuard VPN |
| Goldilocks | WireGuard VPN |

All internal dashboards are accessible only through the WireGuard VPN.

See `docs/RUNBOOK.md` for operational access instructions.

---

## Documentation

| Document | Description |
|---|---|
| `docs/ARCHITECTURE.md` | Infrastructure layout and traffic flows |
| `docs/SECURITY.md` | Policies, runtime security, and supply chain controls |
| `docs/RUNBOOK.md` | Operational procedures and troubleshooting |
| `docs/TESTING.md` | Validation and deployment checks |
| `docs/CONTRIBUTING.md` | Development workflow and conventions |

---

## Stack Overview

<details>
<summary>Full component list</summary>

### Infrastructure & Storage

- AWS EKS — Managed Kubernetes control plane running ARM64 Graviton worker nodes
- Karpenter — Just-in-time compute provisioning with automated node consolidation
- AWS RDS MySQL — Multi-AZ relational database layer
- AWS S3 — Object storage for backups and Loki retention
- AWS ECR — Private container registry with immutable image tags

### Networking & Edge Traffic

- AWS Transit Gateway — Central hub connecting WireGuard, dev, and prod VPCs
- Istio — Service mesh for mTLS and traffic routing
- Cilium — eBPF-based networking and policy enforcement
- AWS NLB — Public and internal load balancing
- ExternalDNS — DNS automation for Cloudflare and Route53
- cert-manager — Automated TLS certificate management

### GitOps & Progressive Delivery

- ArgoCD — Declarative GitOps reconciliation (one instance per environment)
- Argo Rollouts — Canary deployments with automated analysis
- GitHub Actions — Multi-arch CI/CD pipelines

### Observability & Alerting

- kube-prometheus-stack — Metrics collection and dashboards
- Loki + Alloy — Centralised log aggregation
- CloudWatch Exporter — AWS metric integration for Prometheus
- Alertmanager + Notifications — Slack and email alert routing

### Security & Governance

- Kyverno — Admission control and policy enforcement
- Falco — Runtime threat detection using eBPF
- Trivy Operator — Continuous vulnerability scanning
- Cosign — OCI image signing and attestations
- External Secrets Operator — AWS Secrets Manager integration via IRSA

### Workload Autoscaling

- KEDA — Event-driven autoscaling with scale-to-zero
- HPA — CPU and memory based autoscaling
- Goldilocks — Resource recommendation dashboards
- VPA — Recommendation-only vertical autoscaling

### Backup & Disaster Recovery

- Velero — Cluster backup and EBS snapshot orchestration

</details>