# Testing

Validation procedures after initial deployment or any significant change.
Run in order — each section depends on the previous passing.

## 1. Infrastructure

```bash
# All nodes ready
kubectl get nodes
# Expected: all nodes STATUS=Ready

# Karpenter controller healthy
kubectl get pods -n karpenter
# Expected: Running

# Verify bootstrap node has correct label
kubectl get nodes -l node-type=karpenter-bootstrap
```

## 2. Platform Health

```bash
# All ArgoCD applications synced and healthy (VPN required)
argocd app list
# Expected: all Sync=Synced, Health=Healthy

# All platform pods running
kubectl get pods -n karpenter
kubectl get pods -n monitoring
kubectl get pods -n security
kubectl get pods -n autoscaling
kubectl get pods -n velero
kubectl get pods -n istio-ingress
kubectl get pods -n kyverno
```

## 3. Application Health

```bash
# All petclinic services running
kubectl get pods -n petclinic
# Expected: all Running, all containers Ready

# Services registered with Eureka
kubectl logs -n petclinic \
  -l app=discovery-server --tail=50 | grep "Registered instance"

# Config server responding
kubectl run -it --rm config-test \
  --image=curlimages/curl \
  --restart=Never -n petclinic \
  -- curl http://config-server-svc:8888/actuator/health
# Expected: {"status":"UP"}
```

## 4. External Access

```bash
# Public app accessible
curl -I https://petclinic.lefrancis.org
# Expected: HTTP 200

# TLS certificate valid
curl -v https://petclinic.lefrancis.org 2>&1 | grep "SSL certificate verify"
# Expected: SSL certificate verify ok

# Internal dashboards NOT accessible without VPN
curl --max-time 5 https://grafana.lefrancis.org
# Expected: timeout or NXDOMAIN — not a public IP
```

## 5. VPN and Internal Access

```bash
# Connect VPN
wg-quick up wg0

# Internal hostnames resolve to private IPs
nslookup grafana.lefrancis.org
# Expected: private IP (10.x.x.x)

# Dashboards accessible with VPN
curl -I https://grafana.lefrancis.org
curl -I https://argocd.lefrancis.org
# Expected: HTTP 200 or 302 redirect to login
```

## 6. mTLS Verification

```bash
# Verify mTLS is enforced in petclinic namespace
istioctl authn tls-check \
  customers-service-svc.petclinic.svc.cluster.local

# Expected output includes:
# STATUS     SERVER     CLIENT     AUTHN POLICY     DESTINATION RULE
# OK         mTLS       mTLS       ...

# Verify STRICT mode is active
kubectl get peerauthentication -n petclinic
# Expected: petclinic-strict-mtls with mode STRICT
```

## 7. Network Policy

```bash
# Verify default deny is in place
kubectl get networkpolicy default-deny-all -n petclinic

# Verify inter-service communication works through allowed paths
# (Run from a pod inside petclinic namespace)
kubectl run -it --rm nettest \
  --image=curlimages/curl \
  --restart=Never -n petclinic \
  -- curl http://config-server-svc:8888/actuator/health
# Expected: HTTP 200 (allowed path)

# Verify blocked paths are denied
kubectl run -it --rm nettest \
  --image=curlimages/curl \
  --restart=Never -n petclinic \
  -- curl --max-time 5 http://visits-service-svc:8082/actuator/health
# Expected: timeout (not allowed — visits is not a config server client)
```

## 8. Supply Chain Security

```bash
# Unsigned image rejected by Kyverno
kubectl run unsigned-test \
  --image=nginx:latest \
  -n petclinic \
  --restart=Never
# Expected: Error from Kyverno — image not signed

# Signed image accepted
kubectl run signed-test \
  --image=509194952955.dkr.ecr.us-east-2.amazonaws.com/springboot/api-gateway:<tag> \
  -n petclinic \
  --restart=Never
# Expected: pod created (clean up after: kubectl delete pod signed-test -n petclinic)

# Verify attestation exists on an image
cosign verify-attestation \
  --type vuln \
  --certificate-identity-regexp "github.com/silasfrancis" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  509194952955.dkr.ecr.us-east-2.amazonaws.com/springboot/customers-service:<tag>
```

## 9. Canary Deployment

```bash
# Deploy a new image version by updating the tag
kubectl argo rollouts set image customers-service \
  customers-service=509194952955.dkr.ecr.us-east-2.amazonaws.com/springboot/customers-service:<new-tag> \
  -n petclinic

# Watch canary progress
kubectl argo rollouts get rollout customers-service \
  -n petclinic --watch

# Verify traffic split in Grafana Istio dashboard
# https://grafana.lefrancis.org (VPN required)
# Check: istio_requests_total split by destination_version

# Verify analysis runs
kubectl get analysisrun -n petclinic

# Let it complete naturally or promote manually
kubectl argo rollouts promote customers-service -n petclinic
```

## 10. Observability

```bash
# Prometheus targets healthy
# https://prometheus.lefrancis.org/targets (VPN required)
# All petclinic targets should be UP

# Metrics flowing
kubectl run -it --rm prom-test \
  --image=curlimages/curl \
  --restart=Never -n petclinic \
  -- curl "http://platform-monitoring-prometheus.monitoring:9090/api/v1/query?query=up{namespace='petclinic'}"
# Expected: all services showing up=1

# Logs flowing to Loki
# In Grafana Explore → Loki:
# {namespace="petclinic"} | json
# Should return recent log lines
```

## 11. Backup

```bash
# Trigger a test backup
velero backup create smoke-test \
  --include-namespaces petclinic \
  --wait

velero backup describe smoke-test
# Expected: Phase: Completed

# Clean up
velero backup delete smoke-test
```

## 12. KEDA Scale to Zero

```bash
# Verify genai-service is scaled to zero with no traffic
kubectl get pods -n petclinic -l app=genai-service
# Expected: 0 pods (after 5 minute cooldown period)

# Send traffic to trigger scale up
curl https://petclinic.lefrancis.org/api/genai/health

# Watch scale up
kubectl get pods -n petclinic -l app=genai-service --watch
# Expected: pod appears within ~30 seconds
```