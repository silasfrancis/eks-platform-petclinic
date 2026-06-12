# Private Hosted Zone
#
# Route53 private hosted zone for internal.lefrancis.org, associated with
# the cluster VPC. Used for internal dashboard DNS (Grafana, ArgoCD,
# Prometheus, Loki) — only resolvable from within the VPC or over the
# WireGuard VPN via the Transit Gateway. ExternalDNS (Route53 provider)
# manages records in this zone.

resource "aws_route53_zone" "private" {
  name = "internal.lefrancis.org" 

  vpc {
    vpc_id = var.vpc_id
  }

  tags = merge(
      {
        Name = "${var.cluster_name}-private-zone"
      },
      var.extended_tags
    )
}