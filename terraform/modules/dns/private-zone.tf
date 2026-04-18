resource "aws_route53_zone" "private" {
  name = "lefrancis.org" 

  vpc {
    vpc_id = var.vpc_id
  }

  tags = {
    Name        = "${var.cluster_name}-private-zone"
    resource = "route53"
  }
}