resource "aws_security_group" "wireguard_server" {
  count = var.enable_wireguard ? 1 : 0

  description = "Security group for wireguard server"
  name        = "wireguard-server-security_group"
  vpc_id      = var.vpc_id
  tags = var.extended_tags

  lifecycle {
    ignore_changes = [
      tags,
      tags_all,
    ]
  }
}

resource "aws_vpc_security_group_ingress_rule" "wireguard_ingress_rule" {
  count = var.enable_wireguard ? 1 : 0

  description       = "Allow inbound WireGuard traffic"
  security_group_id = aws_security_group.wireguard_server[0].id
  from_port         = 51820
  to_port           = 51820
  ip_protocol       = "udp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "wireguard_egress_all" {
  count = var.enable_wireguard ? 1 : 0

  description       = "Allow all outbound traffic for VPN clients"
  security_group_id = aws_security_group.wireguard_server[0].id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}