# Changelog

All notable changes to this platform are documented here.

---

## [Unreleased]

### Added

- AWS Transit Gateway connecting WireGuard, dev, and prod VPCs with explicit route tables
- Dedicated WireGuard VPC isolated from application environments
- TGW route table isolation — explicit black-hole routes blocking dev ↔ prod traffic
- Separate ArgoCD instance per environment — each cluster fully self-contained
- `env/global/networking/transit-gateway/` Terraform module for TGW and all attachments
- `env/global/networking/wireguard/` Terraform module for WireGuard VPC and EC2
- `env/global/app-registry/` Terraform module (renamed from shared-resources)
- `env/global/bootstrap/` Terraform module for S3 state backend
- Five-layer Terraform provisioning order documented in README
- `task tf:wireguard:*` tasks for WireGuard infrastructure lifecycle
- `task tf:tgw:*` tasks for Transit Gateway infrastructure lifecycle
- `task tf:app-registry:*` tasks replacing old `tf:resources:*` tasks
- Environment-aware RDS cost controls — instance class, Multi-AZ, log exports,
  Enhanced Monitoring, backup retention, deletion protection, final snapshot
- Environment-aware NAT Gateway count — single in dev, per-AZ in prod
- Environment-aware EKS control plane logs — disabled in dev, api + audit in prod
- Environment-aware CloudWatch log retention — 7 days dev, 30 days prod
- Environment-aware KMS deletion window — 7 days dev, 30 days prod
- RDS automated backup Lambda disabled in dev via `count = local.is_prod ? 1 : 0`

### Changed

- WireGuard server moved from prod VPC to dedicated WireGuard VPC
- VPC peering replaced with Transit Gateway for multi-VPC connectivity
- ArgoCD multi-cluster management replaced with per-environment ArgoCD instances
- Terraform shared networking split into independent WireGuard and Transit Gateway layers
- `tf:resources:*` tasks renamed to `tf:app-registry:*` throughout
- `platform:up` task updated to reflect five-layer provisioning order
- Infrastructure provisioning section in README updated to five steps
- ARCHITECTURE.md updated — VPC peering section replaced with Transit Gateway section
- ARCHITECTURE.md updated — ArgoCD multi-cluster section replaced with per-env model
- Design decision updated — Transit Gateway over VPC Peering rationale documented
- Design decision updated — Dedicated WireGuard VPC rationale documented
- Design decision added — Separate ArgoCD per environment rationale documented

### Fixed

- `SHARED_RESOURCES_DIR` variable was undefined in terraform Taskfile — replaced
  with explicit `APP_REGISTRY_DIR` variable
- `SHARED_NETWORKING_DIR` variable was undefined in terraform Taskfile — replaced
  with separate `WIREGUARD_DIR` and `TGW_DIR` variables
- `transit_gateway_default_route_table_association` not set on TGW VPC attachments —
  now explicitly set to `false` on all three attachments
- Missing `depends_on` on VPC route resources — TGW attachments take 30-60s to
  become available, routes now depend on their respective attachment

---

## [0.2.0] — Networking and GitOps Enhancements

### Added

- Dual-gateway architecture — public NLB + private internal NLB
- Route53 private hosted zone for internal dashboard DNS
- WireGuard VPN server provisioned via Terraform, configured via Ansible over SSM
- Ansible playbook for WireGuard server configuration (SSM-based, no SSH)
- ExternalDNS split into separate Cloudflare and Route53 instances with annotation filters
- AnalysisTemplate for automated Prometheus-based canary validation
- Cosign vulnerability attestation in CI pipeline
- VPA objects for all petclinic microservices in Goldilocks recommendation mode

### Changed

- ArgoCD and all internal dashboards moved behind WireGuard VPN
- Gateway values refactored to map pattern — supports N gateways with no template changes
- CI pipeline removed ArgoCD sync step — ArgoCD polls Git directly

---

## [0.1.0] — Initial Platform Build

### Added

- EKS cluster with Karpenter on Graviton ARM64 (t4g instances, us-east-2)
- Istio service mesh with mTLS STRICT mode
- ArgoCD App of Apps with sync wave ordering
- Argo Rollouts canary deployments with Istio traffic splitting
- kube-prometheus-stack with 7 Grafana dashboards and 30+ PrometheusRules
- Loki + Alloy log aggregation with S3 backend
- CloudWatch Exporter for RDS metrics
- Kyverno policy enforcement with image signature verification
- Falco runtime security with eBPF driver and custom petclinic rules
- Trivy Operator continuous scanning with EKS CIS compliance
- Velero backup — daily cluster + hourly petclinic + daily monitoring
- KEDA scale-to-zero for genai-service
- Goldilocks VPA resource rightsizing
- cert-manager wildcard TLS via Let's Encrypt DNS-01 + Cloudflare
- ExternalDNS Cloudflare integration
- External Secrets Operator with AWS Secrets Manager backend
- GitHub Actions CI pipeline with multi-arch builds, Trivy scanning, Cosign signing
- Shared microservice Helm chart with policy-as-data values architecture
- Cilium NetworkPolicy with default-deny-all and per-service allow rules
