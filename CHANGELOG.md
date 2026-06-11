# Changelog

All notable changes to this platform are documented here.

---

## [Unreleased]

## [1.0.0] — EKS Platform Architecture

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
- Environment-aware RDS cost controls — instance class, Multi-AZ, log exports, Enhanced Monitoring, backup retention, deletion protection, final snapshot
- Environment-aware NAT Gateway count — single in dev, per-AZ in prod
- Environment-aware EKS control plane logs — disabled in dev, api + audit in prod
- Environment-aware CloudWatch log retention — 7 days dev, 30 days prod
- Environment-aware KMS deletion window — 7 days dev, 30 days prod
- RDS automated backup Lambda disabled in dev via `count = local.is_prod ? 1 : 0`
- GitHub Actions workflow for Helm values update pull request validation
- GitHub Actions workflow for automatic approval of trusted Helm values update pull requests
- GitHub Actions workflow for automatic cleanup of stale Helm values update pull requests
- Istio AuthorizationPolicy resources for L7 workload authorization and RBAC enforcement

### Changed

- WireGuard server moved from prod VPC to dedicated WireGuard VPC
- VPC peering replaced with Transit Gateway for multi-VPC connectivity
- ArgoCD multi-cluster management replaced with per-environment ArgoCD instances
- Terraform shared networking split into independent WireGuard and Transit Gateway layers
- `tf:resources:*` tasks renamed to `tf:app-registry:*` throughout
- `platform:up` task updated to reflect five-layer provisioning order
- Infrastructure provisioning section in README updated to five steps
- ARCHITECTURE.md updated — VPC peering section replaced with Transit Gateway section
- ARCHITECTURE.md updated — ArgoCD multi-cluster section replaced with per-environment model
- Design decision updated — Transit Gateway over VPC Peering rationale documented
- Design decision updated — Dedicated WireGuard VPC rationale documented
- Design decision added — Separate ArgoCD per environment rationale documented
- Cilium NetworkPolicy resources replaced with standard Kubernetes NetworkPolicy resources
- Network security model updated to use Kubernetes NetworkPolicy for L4 traffic control and Istio AuthorizationPolicy for L7 authorization

### Fixed

- `SHARED_RESOURCES_DIR` variable was undefined in terraform Taskfile — replaced with explicit `APP_REGISTRY_DIR` variable
- `SHARED_NETWORKING_DIR` variable was undefined in terraform Taskfile — replaced with separate `WIREGUARD_DIR` and `TGW_DIR` variables
- `transit_gateway_default_route_table_association` not set on TGW VPC attachments — now explicitly set to `false` on all three attachments
- Missing `depends_on` on VPC route resources — TGW attachments take 30–60 seconds to become available, routes now depend on their respective attachment