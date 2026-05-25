# Runbook

Operational reference for the platform.

---

# Domain Configuration

The repository uses `lefrancis.org` as the default domain.

Before deployment, update the ingress and DNS values to use your own domain.

Files to update:

```text
k8s/platform/ingress/values.yaml
k8s/platform/ingress/values-<env>.yaml
k8s/platform/external-dns/
k8s/platform/cert-manager/
```

Typical values to replace:

```yaml
petclinic.lefrancis.org
argocd.lefrancis.org
grafana.lefrancis.org
prometheus.lefrancis.org
loki.lefrancis.org
goldilocks.lefrancis.org
```

Also update:
- Cloudflare zone configuration
- Route53 private hosted zone names
- cert-manager ClusterIssuer email/domain values if required

Internal dashboards use private Route53 records and resolve only through the WireGuard VPN.

---

# VPN Access

Internal services are reachable only through WireGuard.

The WireGuard server runs in the prod VPC and routes traffic to both:
- prod cluster (`10.0.0.0/16`)
- dev cluster (`10.1.0.0/16`)

through VPC peering.

```bash
# Connect
wg-quick up wg0

# Verify DNS resolution through the VPN
nslookup grafana.lefrancis.org

# Expected:
# Private/internal IP
# NOT a public IP

# Disconnect
wg-quick down wg0
```

WireGuard client configurations are generated directly on the VPN server under:

```text
/etc/wireguard/clients/
```

Retrieve the client config from the server through SSM access.

---

# Internal Dashboards

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

# Grafana credentials
aws secretsmanager get-secret-value \
  --secret-id <secret path where grafana credentials are stored> \
  --query SecretString \
  --output text | jq .
```

---

# Deployments

## Standard Deployment

Push changes to the tracked branch.

CI pipeline:
- builds multi-arch images
- runs Trivy scans
- signs images with Cosign
- pushes images to ECR
- updates Helm image tags

ArgoCD detects the change and syncs automatically.
Argo Rollouts manages the canary deployment.

```bash
git push origin dev
```

Monitor rollout progress:

```bash
kubectl argo rollouts get rollout customers-service \
  -n petclinic \
  --watch
```

---

## Promote a Canary

```bash
kubectl argo rollouts promote customers-service \
  -n petclinic
```

---

## Roll Back a Deployment

```bash
# Roll back to previous stable revision
kubectl argo rollouts undo customers-service \
  -n petclinic

# Roll back to a specific revision
kubectl argo rollouts undo customers-service \
  -n petclinic \
  --to-revision=3

# View rollout history
kubectl argo rollouts history rollout customers-service \
  -n petclinic
```

---

## Force ArgoCD Sync

VPN access required.

```bash
argocd app sync customers-service

# Sync all applications
argocd app sync --all
```

---

# Scaling

```bash
# Temporarily scale a rollout
kubectl scale rollout customers-service \
  -n petclinic \
  --replicas=5

# View HPA status
kubectl get hpa -n petclinic

# View KEDA ScaledObjects
kubectl get scaledobject -n petclinic

# View Karpenter node provisioning
kubectl get nodeclaims
```

---

# Observability

## Logs

```bash
# Stream service logs
kubectl logs -n petclinic \
  -l app=customers-service \
  -f \
  --tail=100

# Logs from a specific pod
kubectl logs -n petclinic <pod-name> \
  -c customers-service
```

Example Loki LogQL queries:

```logql
# All application errors
{namespace="petclinic"} | json | level="error"

# Single service
{namespace="petclinic", app="customers-service"} | json
```

---

## Metrics

```bash
# Check Prometheus targets
# VPN required
https://prometheus.lefrancis.org/targets
```

---

# Backup and Restore

```bash
# List backups
velero backup get

# Create manual backup
velero backup create manual-$(date +%Y%m%d-%H%M) \
  --include-namespaces petclinic \
  --wait

# Describe backup
velero backup describe <backup-name> --details

# Restore backup
velero restore create \
  --from-backup <backup-name> \
  --include-namespaces petclinic \
  --wait

# Check restore status
velero restore describe <restore-name>
```

---

# Secrets Rotation

```bash
# Update secret value
aws secretsmanager put-secret-value \
  --secret-id dev/petclinic/customers-service \
  --secret-string '{"db_password":"new-value"}'

# Force ESO refresh
kubectl annotate externalsecret customers-service-secrets \
  -n petclinic \
  force-sync=$(date +%s) \
  --overwrite
```

---

# Certificate Management

```bash
# Check certificates
kubectl get certificates -n istio-ingress

# Validate ClusterIssuer
kubectl get clusterissuer letsencrypt-cloudflare -o yaml

# Force certificate re-issuance
kubectl delete secret petclinic-public-tls \
  -n istio-ingress

# Monitor issuance
kubectl describe certificate petclinic-public-tls \
  -n istio-ingress
```

---

# Node Management

```bash
# List Karpenter-managed nodes
kubectl get nodes -l karpenter.sh/nodepool

# Drain node
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

# WireGuard Server Management

The WireGuard server is provisioned through Terraform and configured through Ansible over AWS SSM. No SSH access is enabled.

```bash
# Re-apply WireGuard configuration
cd ansible

ansible-playbook \
  -i inventory.yaml \
  wireguard.yaml

# Start SSM session
aws ssm start-session \
  --target <instance-id> \
  --region us-east-2

# Check tunnel status inside the instance
sudo wg show
```

---

# Alerts Reference

| Alert | Severity | Meaning | Action |
|---|---|---|---|
| ArgoAppNotSynced | Warning | App not synced for 12h | Check ArgoCD sync status |
| ArgoAppHealthDegraded | Critical | Application unhealthy | Check pod logs and events |
| VeleroBackupFailed | Critical | Backup job failed | Check Velero controller logs |
| VeleroNoNewBackup | Critical | No backup in 25h | Verify schedules and storage |
| KarpenterNodeNotLaunched | Warning | Node provisioning failure | Check EC2 limits and Karpenter logs |

---

# Common Issues

## Pods Stuck in Pending

```bash
kubectl describe pod <pod-name> -n petclinic

# Check:
# - insufficient CPU/memory
# - taints
# - affinity rules

kubectl get nodeclaims
```

---

## ArgoCD Sync Stuck or Degraded

VPN required.

```bash
# Check Kyverno policy reports
kubectl get policyreport -n petclinic

# Check failed hook jobs
kubectl get jobs -n petclinic

# Force refresh
argocd app get <app-name> --hard-refresh
```

---

## Image Pull Errors

```bash
aws ecr describe-images \
  --repository-name springboot/customers-service \
  --region us-east-2 \
  --query 'imageDetails[*].imageTags'
```

---

## Canary Stuck in Analysis

```bash
kubectl get analysisrun -n petclinic

kubectl describe analysisrun <name> \
  -n petclinic

# Verify Prometheus connectivity
kubectl run -it --rm debug \
  --image=curlimages/curl \
  --restart=Never \
  -n petclinic \
  -- curl http://platform-monitoring-prometheus.monitoring:9090/-/healthy
```

---

## Internal Dashboard Not Resolving

```bash
# Verify VPN connection
wg show

# Verify DNS resolution
nslookup grafana.lefrancis.org

# Expected:
# Private/internal IP
# NOT a public IP

# Verify Route53 private record
aws route53 list-resource-record-sets \
  --hosted-zone-id <zone-id> \
  --query "ResourceRecordSets[?Name=='grafana.lefrancis.org.']"
```