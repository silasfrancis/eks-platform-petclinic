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