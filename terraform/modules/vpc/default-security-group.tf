# Default Security Group (Locked Down)
#
# The VPC's default security group is implicitly attached to any resource
# that doesn't specify one. Stripped of all ingress/egress rules so it can't
# be accidentally relied upon — every resource must use an explicit, purpose-built security group.

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.vpc.id
  ingress = []
  egress  = []

  tags = merge(
    { Name     = "${var.vpc_name_prefix}-${var.env}-default-sg-do-not-use"}
    , var.extended_tags
  )
}