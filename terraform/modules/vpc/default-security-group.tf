# Default Security Group Locked Down)
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.vpc.id
  ingress = []
  egress  = []

  tags = merge(
    { Name     = "${var.vpc_name_prefix}-${var.env}-default-sg-do-not-use"}
    , var.extended_tags
  )
}