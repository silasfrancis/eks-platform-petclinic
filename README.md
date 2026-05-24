# PetClinic Platform

Kubernetes platform on AWS EKS built around the Spring PetClinic microservices application.

The repository combines infrastructure provisioning, GitOps delivery, cluster networking, autoscaling, observability, runtime security, and operational tooling in a single environment.

![Architecture](docs/diagrams/aws-architecture.drawio.svg)

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
| GitOps | ArgoCD (App of Apps) |
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
├── terraform/      # AWS infrastructure
├── k8s/            # Kubernetes platform and GitOps resources
│   ├── platform/   # Istio, monitoring, autoscaling, security, backups
│   ├── argocd/     # App of Apps configuration
│   ├── bootstrap/  # Cluster bootstrap components
│   └── microservices/ # Shared Helm chart for all microservices
├── services/       # Spring Boot microservices
├── ansible/        # WireGuard configuration
├── migrations/     # Database migrations
├── docs/           # Documentation and diagrams
└── scripts/        # Validation and helper scripts
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

### 1. Bootstrap Terraform State

```bash
cd terraform/env/shared/bootstrap

# Create S3 backend buckets for any environment
terraform init

# Review planned backend resources
terraform plan -var-file=terraform.tfvars -out=tfplan

# Apply backend infrastructure
terraform apply tfplan
```

### 2. Provision Environment Infrastructure

```bash
cd terraform/env/main

# Initialize Terraform using partial backend configuration
terraform init -backend-config=state.conf

# Review infrastructure changes for the EKS environment
terraform plan -var-file=terraform.tfvars -out=tfplan

# Provision VPC, EKS, IAM, RDS, and platform infrastructure
terraform apply tfplan
```

### 3. Provision Shared Networking

```bash
cd terraform/env/shared/networking

# Initialize Terraform backend
terraform init -backend-config=state.conf

# Review shared networking resources
terraform plan -var-file=terraform.tfvars -out=tfplan

# Provision WireGuard server, VPC peering, and shared routing
terraform apply tfplan
```

---

## WireGuard Setup

WireGuard runs on a public EC2 instance inside the production VPC and is configured through Ansible over AWS SSM.

The server acts as the single VPN entry point for both environments:
- direct access to the production EKS cluster
- routed access to the development EKS cluster through VPC peering

```bash
cd ansible

# Configure the WireGuard server
ansible-playbook -i inventory.yaml wireguard.yaml

# Verify WireGuard tunnel status
ansible all -i inventory.yaml \
  -m shell \
  -a "sudo wg show"
```

After setup:
1. Retrieve the generated client configuration
2. Import it into your WireGuard client
3. Connect to the VPN before accessing internal services

Once connected, the VPN can reach:
- production workloads directly inside the prod VPC
- development workloads through cross-VPC routing over the peering connection

---

## Configure kubectl

```bash
aws eks update-kubeconfig \
  --region us-east-2 \
  --name <cluster-name> \
  --role-arn arn:aws:iam::<account-id>:role/EKSAdminRole # role given EKS access entry via terraform
```

---

## Bootstrap the Cluster

```bash
cd k8s

# Install base platform components
task bootstrap ENV=prod CLUSTER_NAME=<cluster-name>

# Deploy platform services, policies, and workloads
task deploy_all ENV=prod
```

---

## Verification

```bash
# Verify worker nodes are registered
kubectl get nodes

# Verify platform workloads across all namespaces
kubectl get pods -A

# Verify PetClinic services are running
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
See [RUNBOOK.md](docs/RUNBOOK.md#vpn-access) for setup instructions.

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

**Infrastructure & Storage**
* AWS EKS 1.35 — Managed Kubernetes control plane running *ARM64* Graviton worker nodes
* Karpenter 1.0.0 — Just-in-time compute provisioning with automated node consolidation
* AWS RDS MySQL — High-availability *Multi-AZ* application database layer
* AWS S3 — Object storage tier for Velero backups, RDS LTR backups and Grafana Loki log retention
* AWS ECR — Secure private container registry for immutable image tags

**Networking & Edge Traffic**
* Istio — Service mesh controlling *STRICT* mTLS enforcement and *VirtualService* traffic routing
* Cilium — Advanced CNI managing eBPF-based network policy segmentation matrices
* AWS NLB — Network Load Balancers provisioning public and internal entry gateways
* ExternalDNS — Automated ingress-to-IP synchronization for Cloudflare and Route53 zones
* cert-manager — Automated X.509 TLS certificate issuance via Let's Encrypt Wildcard providers

**GitOps & Progressive Delivery**
* ArgoCD — GitOps continuous delivery engine executing *App-of-Apps* declarative state reconciliation
* Argo Rollouts — Progressive delivery controller managing automated, metric-analyzed canary promotions
* GitHub Actions — Distributed CI pipeline for multi-arch image building, scanning, and registry pushing

**Observability & Alerting**
* kube-prometheus-stack — Integrated Prometheus time-series metrics collection and Grafana dashboard visualization
* Loki + Grafana Alloy — Cloud-native log aggregation streaming cluster-wide stdout logs to S3 storage
* CloudWatch Exporter — Bridge agent pulling native AWS RDS resource metrics directly into Prometheus
* Alert Escalation Framework — High-priority routing via Alertmanager, ArgoCD Notifications, and Falco down to Slack channels

**Security & Governance**
* Kyverno — Mutating, validating, and image provenance admission controller verifying image signatures
* Falco — Runtime threat detection scanning Linux kernel events inside the container space using eBPF probes
* Trivy Operator — Continuous in-cluster image vulnerability tracking and static compliance auditing
* Cosign — Cryptographic image signing and OCI artifact attestation validation
* External Secrets Operator (ESO) — Secure parameter sync mapping AWS Secrets Manager payloads to native cluster secrets using IRSA

**Workload Autoscaling**
* KEDA — Event-driven horizontal pod autoscaling supporting scale-to-zero queue/metric behaviors
* HPA — Traditional horizontal pod scaling driven by CPU and Memory utilization profiles
* Goldilocks — VPA dashboard utility identifying container resource footprint anomalies
* Vertical Pod Autoscaler (VPA) — Non-disruptive, recommendation-only resource limit advisor

**Backup & Disaster Recovery**
* Velero — In-cluster backup engine executing scheduled EBS snapshots and S3 control plane state dumps

</details>