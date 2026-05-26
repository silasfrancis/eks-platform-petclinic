# Default Security Group Locked Down)
resource "aws_default_security_group" "default" {
  vpc_id = var.vpc_id
  ingress = []
  egress  = []

  tags = merge(
    { Name     = "${var.app}-${var.env}-default-sg-do-not-use"}
    , var.extended_tags
  )
}