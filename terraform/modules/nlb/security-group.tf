# Security Groups: NLB (Istio Gateway Load Balancers)
#
# Creates security groups for the NLBs provisioned via Kubernetes Service
# type=LoadBalancer for the Istio gateways:
#   - external: public-facing NLB, open to the internet on 80/443
#   - internal: VPN-only NLB, restricted to the WireGuard VPC CIDR on 80/443
#     (used for internal dashboards like Grafana, ArgoCD, etc.)
#
# Ingress rules are generated as a cross-product of nlb_configs x nlb_ports,
# so adding a new port here automatically applies it to both NLB types.


locals {
  # One entry per NLB type
  nlb_configs = {
    external = {
      description   = "Security group for external NLB"
      cidr          = "0.0.0.0/0"
      referenced_sg = null
    }
    internal = {
      description   = "Security group for internal NLB"
      cidr          = var.wireguard_vpc_cidr
      referenced_sg = null
    }
  }

  # Ports exposed on both NLBs
  nlb_ports = [80, 443]

  # Cross-product of nlb_configs and nlb_ports to give one ingress rule per combination
  ingress_rules = flatten([
    for type, config in local.nlb_configs : [
      for port in local.nlb_ports : {
        key           = "${type}_${port}"
        type          = type
        port          = port
        cidr          = config.cidr
        referenced_sg = config.referenced_sg
      }
    ]
  ])
}

# Security Groups (one per NLB type)
# tags/tags_all changes are ignored since the AWS Load Balancer Controller
# adds its own tags to these security groups after creation
resource "aws_security_group" "nlb" {
  for_each = local.nlb_configs

  name        = "${var.app}-${var.env}-nlb-${each.key}-sg"
  description = each.value.description
  vpc_id      = var.vpc_id

  tags = var.extended_tags

  lifecycle {
    ignore_changes = [
      tags,
      tags_all,
    ]
  }
}

# Ingress Rules (HTTP + HTTPS per NLB type)
# External NLB allows 80/443 from anywhere; internal NLB allows 80/443 only
# from the WireGuard VPC CIDR
resource "aws_vpc_security_group_ingress_rule" "nlb" {
  for_each = { for rule in local.ingress_rules : rule.key => rule }

  security_group_id            = aws_security_group.nlb[each.value.type].id
  description                  = "Allow port ${each.value.port} traffic on ${each.value.type} Istio NLB"
  from_port                    = each.value.port
  to_port                      = each.value.port
  ip_protocol                  = "tcp"
  cidr_ipv4                    = each.value.cidr
  referenced_security_group_id = each.value.referenced_sg

}

# Egress Rules
# Allow all outbound traffic from both NLB security groups
resource "aws_vpc_security_group_egress_rule" "nlb" {
  for_each = local.nlb_configs

  security_group_id = aws_security_group.nlb[each.key].id
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

}