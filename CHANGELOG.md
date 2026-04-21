# Changelog

All notable changes to this platform are documented here.

## [Unreleased]

### Added
- Dual-gateway architecture (public NLB + private internal NLB)
- Route53 private hosted zone for internal dashboard DNS
- WireGuard VPN server provisioned via Terraform + configured via Ansible over SSM
- Ansible playbook for WireGuard server configuration (SSM-based, no SSH)
- ExternalDNS split into separate Cloudflare and Route53 instances
- AnalysisTemplate for automated Prometheus-based canary validation
- Cosign vulnerability attestation in CI pipeline
- VPA objects for all petclinic microservices (Goldilocks recommendation mode)

### Changed
- ArgoCD and all internal dashboards moved behind WireGuard VPN
- Gateway values refactored to map pattern — supports N gateways with no template changes
- CI pipeline removed ArgoCD sync step — ArgoCD polls Git directly

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