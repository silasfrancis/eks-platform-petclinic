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
      cidr          = null
      referenced_sg = var.wireguard_server_security_group_id
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
resource "aws_security_group" "nlb" {
  for_each = local.nlb_configs

  name        = "${var.app}-${var.env}-nlb-${each.key}-sg"
  description = each.value.description
  vpc_id      = aws_vpc.main_vpc.id

  tags = { resource = "vpc" }
}

# Ingress Rules (HTTP + HTTPS per NLB type)
resource "aws_vpc_security_group_ingress_rule" "nlb" {
  for_each = { for rule in local.ingress_rules : rule.key => rule }

  security_group_id            = aws_security_group.nlb[each.value.type].id
  description                  = "Allow port ${each.value.port} traffic on ${each.value.type} Istio NLB"
  from_port                    = each.value.port
  to_port                      = each.value.port
  ip_protocol                  = "tcp"
  cidr_ipv4                    = each.value.cidr
  referenced_security_group_id = each.value.referenced_sg

  tags = { resource = "vpc" }
}

# Egress Rules
resource "aws_vpc_security_group_egress_rule" "nlb" {
  for_each = local.nlb_configs

  security_group_id = aws_security_group.nlb[each.key].id
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = { resource = "vpc" }
}