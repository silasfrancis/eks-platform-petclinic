# PetClinic Platform

A production-grade Kubernetes platform on AWS EKS demonstrating platform
engineering practices: GitOps, progressive delivery, multi-layer security,
full observability, and infrastructure as code.

> Spring Boot PetClinic microservices serve as the reference application.

![Architecture](docs/diagrams/architecture.png)

## Platform Highlights

| Concern | Implementation |
|---|---|
| Container orchestration | AWS EKS on Graviton (ARM64) |
| Node provisioning | Karpenter — SPOT + ON_DEMAND NodePools |
| Service mesh | Istio — mTLS + canary traffic splitting |
| GitOps | ArgoCD App of Apps |
| Progressive delivery | Argo Rollouts canary with Prometheus analysis |
| Observability | Prometheus + Grafana + Loki + Alertmanager |
| Supply chain security | Cosign keyless signing + vulnerability attestation |
| Policy enforcement | Kyverno admission control |
| Runtime security | Falco eBPF threat detection |
| Secrets management | AWS Secrets Manager + External Secrets Operator |
| Backup and DR | Velero — S3 + EBS snapshots |
| Autoscaling | HPA + KEDA scale-to-zero + Karpenter consolidation |

## Repository Structure

```
spring_boot_micro_services/
├── .github/workflows/       CI/CD pipelines
├── k8s/
│   ├── apps/microservice/   Shared Helm chart for all 8 microservices
│   ├── argocd/              ArgoCD App of Apps bootstrap
│   ├── platform/
│   │   ├── autoscaling/     KEDA + Goldilocks
│   │   ├── backup/          Velero
│   │   ├── compute/         Karpenter
│   │   ├── ingress/         Istio gateway + ExternalDNS + cert-manager
│   │   ├── monitoring/      kube-prometheus-stack + Loki + Alloy
│   │   └── security/        Trivy + Falco + cert-manager
│   └── policies/            Kyverno policies + NetworkPolicies
└── terraform/               AWS infrastructure
```

## Prerequisites

| Tool | Version | Purpose |
|---|---|---|
| AWS CLI | >= 2.x | AWS authentication |
| kubectl | >= 1.29 | Cluster management |
| helm | >= 3.14 | Chart operations |
| terraform | >= 1.7 | Infrastructure provisioning |
| ansible | >= 2.15 | WireGuard server configuration |
| task | >= 3.x | Bootstrap automation |
| argocd | >= 2.10 | ArgoCD CLI |

## Getting Started

### 1. Provision Infrastructure

```bash
cd terraform
terraform init
terraform plan -var-file=environments/dev.tfvars
terraform apply -var-file=environments/dev.tfvars
```

### 2. Configure WireGuard Server

The WireGuard server runs on a private EC2 instance.
Ansible configures it via AWS SSM — no SSH port required.

```bash
cd ansible
ansible-playbook wireguard.yml \
  -i inventory/dev.yml \
  --extra-vars "env=dev"
```

Connect to VPN before proceeding — internal dashboards and
ArgoCD are only accessible via WireGuard.

```bash
wg-quick up wg0
```

### 3. Configure kubectl

```bash
aws eks update-kubeconfig \
  --region us-east-2 \
  --name <cluster-name>
```

### 4. Bootstrap the Platform

```bash
# Install pre-ArgoCD dependencies
task install_istio
task install_vpa
task install_external_secrets
task install_argo_rollouts

# Install ArgoCD
task install_argocd

# Deploy App of Apps — ArgoCD manages everything from here
task deploy_root_app
```

### 5. Verify Platform Health

```bash
# Check all ArgoCD applications are synced and healthy
task argocd_status

# Verify nodes are provisioned
kubectl get nodes

# Check all petclinic pods are running
kubectl get pods -n petclinic
```

## Accessing Services

| Service | URL | Access |
|---|---|---|
| PetClinic | https://petclinic.lefrancis.org | Public |
| ArgoCD | https://argocd.lefrancis.org | WireGuard VPN |
| Grafana | https://grafana.lefrancis.org | WireGuard VPN |
| Prometheus | https://prometheus.lefrancis.org | WireGuard VPN |
| Loki | https://loki.lefrancis.org | WireGuard VPN |

Internal dashboards require an active WireGuard VPN connection.
See [RUNBOOK.md](docs/RUNBOOK.md#vpn-access) for setup instructions.

## Documentation

| Document | Contents |
|---|---|
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | System design, component decisions, traffic flows |
| [SECURITY.md](docs/SECURITY.md) | Security model, supply chain, secrets management |
| [RUNBOOK.md](docs/RUNBOOK.md) | Day 2 operations, troubleshooting, common tasks |
| [TESTING.md](docs/TESTING.md) | Validation procedures after deployment or changes |
| [CONTRIBUTING.md](docs/CONTRIBUTING.md) | Development workflow, conventions |

## Tech Stack

<details>
<summary>Full component list</summary>

**Infrastructure**
- AWS EKS 1.35 — managed Kubernetes
- Karpenter 1.0.0 — node autoprovisioning
- AWS RDS MySQL — application database
- AWS S3 — log and backup storage
- AWS ECR — container registry

**Networking**
- Istio 1.24 — service mesh, mTLS, traffic management
- Cilium — CNI with NetworkPolicy enforcement
- AWS NLB — load balancing (EKS Cloud Provider)
- ExternalDNS — DNS automation (Cloudflare + Route53)
- cert-manager — TLS certificate lifecycle

**GitOps and Delivery**
- ArgoCD 2.13 — GitOps continuous delivery
- Argo Rollouts — canary deployments
- GitHub Actions — CI/CD pipelines

**Observability**
- kube-prometheus-stack — Prometheus + Grafana + Alertmanager
- Loki + Alloy — log aggregation
- CloudWatch Exporter — RDS metrics

**Security**
- Kyverno — admission control and policy enforcement
- Falco — runtime threat detection (eBPF)
- Trivy Operator — continuous vulnerability scanning
- Cosign — image signing and attestation
- External Secrets Operator — secrets management

**Autoscaling**
- KEDA — event-driven autoscaling
- HPA — CPU/memory autoscaling
- Goldilocks — resource rightsizing recommendations
- VPA — vertical pod autoscaler (recommendation mode)

**Backup**
- Velero — Kubernetes backup and DR
