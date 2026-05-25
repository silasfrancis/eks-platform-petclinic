# Runbook

Operational reference for the eks-platform-petclinic platform.

---

## Table of Contents

- [Before You Start](#before-you-start)
  - [Domain Configuration](#domain-configuration)
- [VPN Access](#vpn-access)
- [Internal Dashboards](#internal-dashboards)
- [Deployments](#deployments)
  - [Standard Deployment](#standard-deployment)
  - [Promote a Canary](#promote-a-canary)
  - [Roll Back a Deployment](#roll-back-a-deployment)
  - [Force ArgoCD Sync](#force-argocd-sync)
- [Scaling](#scaling)
- [Observability](#observability)
  - [Logs](#logs)
  - [Metrics](#metrics)
- [Backup and Restore](#backup-and-restore)
- [Secrets Rotation](#secrets-rotation)
- [Certificate Management](#certificate-management)
- [Node Management](#node-management)
- [WireGuard Server Management](#wireguard-server-management)
- [Alerts Reference](#alerts-reference)
- [Common Issues](#common-issues)
  - [Pods Stuck in Pending](#pods-stuck-in-pending)
  - [ArgoCD Sync Stuck or Degraded](#argocd-sync-stuck-or-degraded)
  - [Image Pull Errors](#image-pull-errors)
  - [Canary Stuck in Analysis](#canary-stuck-in-analysis)
  - [Internal Dashboard Not Resolving](#internal-dashboard-not-resolving)

---

## Before You Start

### Domain Configuration

The repository uses `lefrancis.org` as the default domain. Before deploying to your own environment, replace all domain references.

Files to update:

```txt
k8s/platform/ingress/values/env/<env>/values.yaml
k8s/platform/monitoring/values/env/<env>/values.yaml
k8s/platform/autoscaling/values/env/<env>/values.yaml
k8s/argocd/values/env/<env>/values.yaml
```

Ingress and dashboard hostnames are configured within the individual chart values files.

Examples:

```yaml
# k8s/platform/ingress/values/env/<env>/values.yaml
petclinic:
  host: petclinic.example.com
```

```yaml
# k8s/platform/monitoring/values/env/<env>/values.yaml
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

```yaml
# k8s/platform/autoscaling/values/env/<env>/values.yaml
goldilocks:
  ingress:
    host: goldilocks.example.com
```

```yaml
# k8s/argocd/values/env/<env>/values.yaml
server:
  ingress:
    hostname: argocd.example.com
```

Hostnames to replace:

```txt
petclinic.lefrancis.org
argocd.lefrancis.org
grafana.lefrancis.org
prometheus.lefrancis.org
loki.lefrancis.org
goldilocks.lefrancis.org
```

Also update:
- Cloudflare or Route53 hosted zones
- Route53 private hosted zone names
- cert-manager ClusterIssuer email configuration

---

## VPN Access

All internal services require an active WireGuard connection.

The WireGuard server runs in the prod VPC (`10.0.0.0/16`) and routes traffic to both clusters via VPC peering:

- prod EKS — `10.0.0.0/16`
- dev EKS — `10.1.0.0/16`

```bash
# Connect
wg-quick up wg0

# Verify DNS resolves to a private IP
nslookup grafana.lefrancis.org
# Expected: private IP — not a public IP

# Disconnect
wg-quick down wg0
```

WireGuard client configs are generated on the VPN server. Retrieve them via SSM before rebuilding the instance.

```bash
aws ssm start-session \
  --target <instance-id> \
  --region us-east-2

# Inside the session
sudo cat /etc/wireguard/clients/<client>.conf
```

---

## Internal Dashboards

| Service | URL |
|---|---|
| ArgoCD | https://argocd.lefrancis.org |
| Grafana | https://grafana.lefrancis.org |
| Prometheus | https://prometheus.lefrancis.org |
| Loki | https://loki.lefrancis.org |
| Goldilocks | https://goldilocks.lefrancis.org |

Retrieve credentials:

```bash
# ArgoCD initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Grafana credentials from Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id <env>/platform-monitoring \
  --query SecretString \
  --output text | jq .
```

---

## Deployments

### Standard Deployment

Push to the tracked branch. CI builds, scans, signs, and pushes the image. ArgoCD detects the updated image tag and syncs. Argo Rollouts manages the canary progression automatically.

```bash
git push origin dev
```

Monitor rollout progress:

```bash
kubectl argo rollouts get rollout customers-service \
  -n petclinic \
  --watch
```

### Promote a Canary

```bash
kubectl argo rollouts promote customers-service \
  -n petclinic
```

### Roll Back a Deployment

```bash
# Roll back to previous stable revision
kubectl argo rollouts undo customers-service -n petclinic

# Roll back to a specific revision
kubectl argo rollouts undo customers-service \
  -n petclinic \
  --to-revision=3

# View rollout history
kubectl argo rollouts history rollout customers-service \
  -n petclinic
```

### Force ArgoCD Sync

VPN access required.

```bash
argocd app sync customers-service

# Sync all applications
argocd app sync --all
```

---

## Scaling

```bash
# Temporarily scale a rollout
kubectl scale rollout customers-service \
  -n petclinic \
  --replicas=5

# View HPA status
kubectl get hpa -n petclinic

# View KEDA ScaledObjects
kubectl get scaledobject -n petclinic

# View Karpenter node provisioning activity
kubectl get nodeclaims
```

---

## Observability

### Logs

```bash
# Stream service logs
kubectl logs -n petclinic \
  -l app=customers-service \
  -f \
  --tail=100

# Logs from a specific pod
kubectl logs -n petclinic <pod-name> -c customers-service
```

Loki LogQL queries:

```logql
# All application errors
{namespace="petclinic"} | json | level="error"

# Single service
{namespace="petclinic", app="customers-service"} | json
```

### Metrics

```txt
# Prometheus targets (VPN required)
https://prometheus.lefrancis.org/targets
```

---

## Backup and Restore

```bash
# List backups
velero backup get

# Create manual backup
velero backup create manual-$(date +%Y%m%d-%H%M) \
  --include-namespaces petclinic \
  --wait

# Describe backup
velero backup describe <backup-name> --details

# Restore from backup
velero restore create \
  --from-backup <backup-name> \
  --include-namespaces petclinic \
  --wait

# Check restore status
velero restore describe <restore-name>
```

---

## Secrets Rotation

```bash
# Update a secret value
aws secretsmanager put-secret-value \
  --secret-id dev/petclinic \
  --secret-string '{"db_password":"new-value"}'

# Force ESO to re-sync immediately
kubectl annotate externalsecret customers-service-secrets \
  -n petclinic \
  force-sync=$(date +%s) \
  --overwrite
```

---

## Certificate Management

```bash
# Check certificate status
kubectl get certificates -n istio-ingress

# Validate ClusterIssuer
kubectl get clusterissuer letsencrypt-cloudflare -o yaml

# Force certificate re-issuance
kubectl delete secret petclinic-public-tls -n istio-ingress

# Monitor issuance progress
kubectl describe certificate petclinic-public-tls -n istio-ingress
```

---

## Node Management

```bash
# List Karpenter-managed nodes
kubectl get nodes -l karpenter.sh/nodepool

# Cordon and drain a node
kubectl cordon <node-name>

kubectl drain <node-name> \
  --ignore-daemonsets \
  --delete-emptydir-data

# View disruption events
kubectl get events \
  -n karpenter \
  --field-selector reason=Disrupting
```

---

## WireGuard Server Management

The WireGuard server is provisioned via Terraform and configured via Ansible over AWS SSM. SSH is not enabled on the instance.

```bash
# Re-apply WireGuard configuration
task ansible:configure_wireguard

# Verify tunnel status
task ansible:check_wireguard

# Start SSM session
aws ssm start-session \
  --target <instance-id> \
  --region us-east-2

# Check tunnel status inside the instance
sudo wg show
```

---

## Alerts Reference

| Alert | Severity | Meaning | Action |
|---|---|---|---|
| ArgoAppNotSynced | Warning | App not synced for 12h | Check ArgoCD sync status and logs |
| ArgoAppHealthDegraded | Critical | Application health degraded | Check pod logs and events |
| VeleroBackupFailed | Critical | Backup job failed | Check Velero controller logs |
| VeleroNoNewBackup | Critical | No backup in 25h | Verify schedules and S3 storage |
| KarpenterNodeNotLaunched | Warning | Node provisioning failed | Check EC2 limits and Karpenter logs |

---

## Common Issues

### Pods Stuck in Pending

```bash
kubectl describe pod <pod-name> -n petclinic
# Check: insufficient resources, taints, affinity rules

kubectl get nodeclaims
# Check: Karpenter has provisioned or is provisioning a node
```

### ArgoCD Sync Stuck or Degraded

VPN required.

```bash
# Check Kyverno policy reports — image may be failing admission
kubectl get policyreport -n petclinic

# Check failed pre-install hook jobs (Flyway migration failure)
kubectl get jobs -n petclinic

# Force a hard refresh
argocd app get <app-name> --hard-refresh
```

### Image Pull Errors

```bash
aws ecr describe-images \
  --repository-name springboot/customers-service \
  --region us-east-2 \
  --query 'imageDetails[*].imageTags'
```

### Canary Stuck in Analysis

```bash
# View active AnalysisRuns
kubectl get analysisrun -n petclinic

# Describe failing AnalysisRun
kubectl describe analysisrun <name> -n petclinic

# Verify Prometheus is reachable from the petclinic namespace
kubectl run -it --rm debug \
  --image=curlimages/curl \
  --restart=Never \
  -n petclinic \
  -- curl http://platform-monitoring-prometheus.monitoring:9090/-/healthy
```

### Internal Dashboard Not Resolving

```bash
# Verify VPN is connected
wg show

# Verify DNS resolves to a private IP
nslookup grafana.lefrancis.org

# Verify Route53 private record exists
aws route53 list-resource-record-sets \
  --hosted-zone-id <zone-id> \
  --query "ResourceRecordSets[?Name=='grafana.lefrancis.org.']"
```