# Runbook

Day 2 operations reference.

## VPN Access

All internal dashboards and ArgoCD require an active WireGuard connection.

```bash
# Connect
wg-quick up wg0

# Verify DNS resolution (confirms VPN is routing correctly)
nslookup grafana.lefrancis.org
# Should resolve to an internal IP — not a public address

# Disconnect
wg-quick down wg0
```

WireGuard client config is stored in AWS Secrets Manager
at `petclinic/wireguard/client-<your-name>`.

```bash
aws secretsmanager get-secret-value \
  --secret-id petclinic/wireguard/client-francis \
  --query SecretString --output text > /etc/wireguard/wg0.conf
```

## Accessing Dashboards

| Service | URL | Notes |
|---|---|---|
| ArgoCD | https://argocd.lefrancis.org | VPN required |
| Grafana | https://grafana.lefrancis.org | VPN required |
| Prometheus | https://prometheus.lefrancis.org | VPN required |
| Loki | https://loki.lefrancis.org | VPN required |

```bash
# ArgoCD initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Grafana credentials
aws secretsmanager get-secret-value \
  --secret-id petclinic/monitoring/grafana \
  --query SecretString --output text | jq .
```

## Deployments

### Normal deployment

Push to the tracked branch — CI builds, scans, signs and pushes the image.
ArgoCD polls Git, detects the image tag change and syncs automatically.
Argo Rollouts runs the canary. Slack notifications confirm each stage.

```bash
git push origin dev
```

Monitor progress:

```bash
kubectl argo rollouts get rollout customers-service \
  -n petclinic --watch
```

### Manually promote a canary

```bash
kubectl argo rollouts promote customers-service -n petclinic
```

### Rollback

```bash
# Roll back to previous stable version
kubectl argo rollouts undo customers-service -n petclinic

# Roll back to a specific revision
kubectl argo rollouts undo customers-service \
  -n petclinic --to-revision=3

# List available revisions
kubectl argo rollouts history rollout customers-service -n petclinic
```

### Force ArgoCD sync (admin only, requires VPN)

```bash
argocd app sync customers-service
argocd app sync --all
```

## Scaling

```bash
# Temporarily override replicas (HPA will reconcile back within minutes)
kubectl scale rollout customers-service -n petclinic --replicas=5

# Check HPA status
kubectl get hpa -n petclinic

# Check KEDA ScaledObject for genai-service
kubectl get scaledobject -n petclinic

# Check Karpenter node provisioning
kubectl get nodeclaims
```

## Observability

```bash
# Tail logs for a service
kubectl logs -n petclinic \
  -l app=customers-service -f --tail=100

# Check a specific pod
kubectl logs -n petclinic <pod-name> -c customers-service

# Loki via Grafana Explore — example LogQL queries:
# All petclinic errors:
# {namespace="petclinic"} | json | level="error"
#
# Specific service:
# {namespace="petclinic", app="customers-service"} | json

# Check Prometheus targets are healthy
# https://prometheus.lefrancis.org/targets (VPN required)
```

## Backup and Restore

```bash
# List all backups
velero backup get

# Trigger a manual backup
velero backup create manual-$(date +%Y%m%d-%H%M) \
  --include-namespaces petclinic \
  --wait

# Describe a backup including warnings
velero backup describe <backup-name> --details

# Restore from backup
velero restore create \
  --from-backup <backup-name> \
  --include-namespaces petclinic \
  --wait

# Check restore status
velero restore describe <restore-name>
```

## Secrets Rotation

```bash
# Update a secret value in AWS Secrets Manager
aws secretsmanager put-secret-value \
  --secret-id dev/petclinic/customers-service \
  --secret-string '{"db_password":"new-value"}'

# ESO syncs within refreshInterval (1h by default)
# Force immediate resync:
kubectl annotate externalsecret customers-service-secrets \
  -n petclinic \
  force-sync=$(date +%s) --overwrite
```

## Certificate Management

```bash
# Check certificate status
kubectl get certificates -n istio-ingress

# Check cert-manager has valid Cloudflare credentials
kubectl get clusterissuer letsencrypt-cloudflare -o yaml

# Force certificate renewal (cert-manager reissues automatically)
kubectl delete secret petclinic-public-tls -n istio-ingress

# Monitor issuance
kubectl describe certificate petclinic-public-tls -n istio-ingress
```

## Node Management

```bash
# List all Karpenter-managed nodes
kubectl get nodes -l karpenter.sh/nodepool

# Drain a node gracefully
kubectl cordon <node-name>
kubectl drain <node-name> \
  --ignore-daemonsets \
  --delete-emptydir-data

# Check Karpenter disruption events
kubectl get events -n karpenter --field-selector reason=Disrupting
```

## WireGuard Server Management

The WireGuard server is managed via Ansible over AWS SSM.
No direct SSH access is configured.

```bash
# Re-run Ansible to update WireGuard config
cd ansible
ansible-playbook wireguard.yml \
  -i inventory/dev.yml \
  --extra-vars "env=dev"

# Open SSM session for manual inspection
aws ssm start-session \
  --target <instance-id> \
  --region us-east-2

# Check WireGuard status on the server (inside SSM session)
sudo wg show
```

## Alerts Reference

| Alert | Severity | Meaning | Action |
|---|---|---|---|
| ArgoAppNotSynced | Warning | App not synced for 12h | Check ArgoCD UI for sync errors |
| ArgoAppHealthDegraded | Critical | App unhealthy for 15m | Check pod logs and events |
| VeleroBackupFailed | Critical | Last backup failed | Check Velero controller logs |
| VeleroNoNewBackup | Critical | No backup in 25h | Check schedule, trigger manual backup |
| KarpenterNodeNotLaunched | Warning | Node not provisioning | Check EC2 limits, Karpenter logs |

## Common Issues

**Pods stuck in Pending**
```bash
kubectl describe pod <pod-name> -n petclinic
# Look for: Insufficient cpu/memory, taints, affinity conflicts
kubectl get nodeclaims
# Check if Karpenter is attempting to provision a node
```

**ArgoCD sync stuck or degraded** (VPN required)
```bash
# Check for Kyverno policy violations
kubectl get policyreport -n petclinic

# Check for failed pre-sync hook jobs
kubectl get jobs -n petclinic

# Hard refresh
argocd app get <app-name> --hard-refresh
```

**Image pull errors**
```bash
# Verify image exists in ECR
aws ecr describe-images \
  --repository-name springboot/customers-service \
  --region us-east-2 \
  --query 'imageDetails[*].imageTags'
```

**Canary stuck in analysis**
```bash
kubectl get analysisrun -n petclinic
kubectl describe analysisrun <name> -n petclinic

# Verify Prometheus is reachable from petclinic namespace
kubectl run -it --rm debug \
  --image=curlimages/curl \
  --restart=Never \
  -n petclinic \
  -- curl http://platform-monitoring-prometheus.monitoring:9090/-/healthy
```

**Internal dashboard not resolving**
```bash
# Confirm VPN is connected
wg show

# Confirm DNS is routing through VPC resolver
nslookup grafana.lefrancis.org
# Should NOT return a public IP

# Check Route53 private zone record exists
aws route53 list-resource-record-sets \
  --hosted-zone-id <zone-id> \
  --query "ResourceRecordSets[?Name=='grafana.lefrancis.org.']"
```