# Testing

Validation procedures after deployment or major platform changes.

The platform may not be running continuously due to AWS infrastructure costs. Public endpoints and internal dashboards may be unavailable if the environment has been intentionally shut down.

If endpoints are unreachable:
- verify the EKS cluster is running
- verify node pools exist
- verify ingress/NLB resources are provisioned
- verify DNS records still point to active load balancers

Run tests in order.

---

# 1. Infrastructure

```bash
# All nodes ready
kubectl get nodes

# Expected:
# STATUS=Ready for all nodes

# Karpenter controller healthy
kubectl get pods -n karpenter

# Verify bootstrap node
kubectl get nodes -l node-type=karpenter-bootstrap
```

---

# 2. Platform Health

```bash
# All ArgoCD applications healthy (VPN required)
argocd app list

# Expected:
# Sync=Synced
# Health=Healthy

# Platform namespaces
kubectl get pods -n karpenter
kubectl get pods -n monitoring
kubectl get pods -n security
kubectl get pods -n autoscaling
kubectl get pods -n velero
kubectl get pods -n istio-ingress
kubectl get pods -n kyverno
```

---

# 3. Application Health

```bash
# Petclinic workloads
kubectl get pods -n petclinic

# Expected:
# Running
# READY containers

# Eureka registration
kubectl logs -n petclinic \
  -l app=discovery-server \
  --tail=50 | grep "Registered instance"

# Config server health
kubectl run -it --rm config-test \
  --image=curlimages/curl \
  --restart=Never \
  -n petclinic \
  -- curl http://config-server-svc:8888/actuator/health

# Expected:
# {"status":"UP"}
```

---

# 4. External Access

Replace domains if you changed them during deployment.

```bash
# Public application
curl -I https://petclinic.lefrancis.org

# Expected:
# HTTP 200

# TLS validation
curl -v https://petclinic.lefrancis.org \
  2>&1 | grep "SSL certificate verify"

# Expected:
# SSL certificate verify ok

# Internal dashboards should not resolve publicly
curl --max-time 5 https://grafana.lefrancis.org

# Expected:
# timeout or NXDOMAIN
```

---

# 5. VPN and Internal Access

```bash
# Connect VPN
wg-quick up wg0

# Internal hostname resolution
nslookup grafana.lefrancis.org

# Expected:
# Private/internal IP

# Internal dashboards reachable
curl -I https://grafana.lefrancis.org
curl -I https://argocd.lefrancis.org

# Expected:
# HTTP 200 or 302
```

---

# 6. mTLS Verification

```bash
# Verify Istio mTLS
istioctl authn tls-check \
  customers-service-svc.petclinic.svc.cluster.local

# Expected:
# STATUS=OK
# CLIENT=mTLS
# SERVER=mTLS

# Verify STRICT mode
kubectl get peerauthentication -n petclinic
```

---

# 7. Network Policy

```bash
# Default deny policy
kubectl get networkpolicy default-deny-all \
  -n petclinic

# Allowed traffic path
kubectl run -it --rm nettest \
  --image=curlimages/curl \
  --restart=Never \
  -n petclinic \
  -- curl http://config-server-svc:8888/actuator/health

# Expected:
# HTTP 200

# Blocked traffic path
kubectl run -it --rm nettest \
  --image=curlimages/curl \
  --restart=Never \
  -n petclinic \
  -- curl --max-time 5 \
  http://visits-service-svc:8082/actuator/health

# Expected:
# timeout
```

---

# 8. Supply Chain Security

```bash
# Unsigned image should fail admission
kubectl run unsigned-test \
  --image=nginx:latest \
  -n petclinic \
  --restart=Never

# Expected:
# Kyverno admission rejection

# Signed image should succeed
kubectl run signed-test \
  --image=509194952955.dkr.ecr.us-east-2.amazonaws.com/springboot/api-gateway:<tag> \
  -n petclinic \
  --restart=Never

# Verify vulnerability attestation
cosign verify-attestation \
  --type vuln \
  --certificate-identity-regexp "github.com/silasfrancis" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  509194952955.dkr.ecr.us-east-2.amazonaws.com/springboot/customers-service:<tag>
```

---

# 9. Canary Deployment

```bash
# Deploy new version
kubectl argo rollouts set image customers-service \
  customers-service=509194952955.dkr.ecr.us-east-2.amazonaws.com/springboot/customers-service:<new-tag> \
  -n petclinic

# Watch rollout
kubectl argo rollouts get rollout customers-service \
  -n petclinic \
  --watch

# Verify AnalysisRuns
kubectl get analysisrun -n petclinic

# Promote manually if needed
kubectl argo rollouts promote customers-service \
  -n petclinic
```

Grafana verification:

```text
https://grafana.lefrancis.org

Istio dashboard:
- verify traffic split
- verify canary/stable versions
- verify request success rate
```

---

# 10. Observability

```bash
# Prometheus query validation
kubectl run -it --rm prom-test \
  --image=curlimages/curl \
  --restart=Never \
  -n petclinic \
  -- curl "http://platform-monitoring-prometheus.monitoring:9090/api/v1/query?query=up{namespace='petclinic'}"

# Expected:
# up=1 for workloads
```

Loki validation:

```logql
{namespace="petclinic"} | json
```

Expected:
- recent log entries
- parsed JSON fields

---

# 11. Backup

```bash
# Trigger test backup
velero backup create smoke-test \
  --include-namespaces petclinic \
  --wait

# Backup status
velero backup describe smoke-test

# Expected:
# Phase: Completed

# Cleanup
velero backup delete smoke-test
```

---

# 12. KEDA Scale to Zero

```bash
# Verify scale-to-zero
kubectl get pods \
  -n petclinic \
  -l app=genai-service

# Expected:
# 0 pods after cooldown period

# Trigger traffic
curl https://petclinic.lefrancis.org/api/genai/health

# Watch scale-up
kubectl get pods \
  -n petclinic \
  -l app=genai-service \
  --watch
```