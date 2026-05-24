# Default Security Group Locked Down)
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main_vpc.id
  ingress = []
  egress  = []

  tags = {
    Name     = "${var.app}-${var.env}-default-sg-do-not-use"
    resource = "vpc"
  }
}