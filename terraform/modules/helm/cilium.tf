resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = "1.19.2"
  namespace  = "kube-system"

  values = [
    yamlencode({
      cni = {
        chainingMode = "aws-cni"
        exclusive    = false
      }

      enableIPv4Masquerade = false
      tunnel               = "disabled"

      hubble = {
        enabled = true
        relay = {
          enabled = true
        }
        ui = {
          enabled = true
        }
      }

      policyEnforcementMode = "default"

      resources = {
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }

      operator = {
        resources = {
          limits = {
            cpu    = "500m"
            memory = "256Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
      }
    })
  ]

  depends_on = [
    aws_eks_addon.vpc_cni,
    aws_eks_node_group.main
  ]

  lifecycle {
    ignore_changes = [
      repository_password
    ]
  }
}