# Elastic IPs for NAT Gateways (based on the number of public subnets each nat-gateway will be placed in)
resource "aws_eip" "nat" {
  for_each = aws_subnet.public
  domain   = "vpc"

  tags = {
    Name     = "${var.app}-${var.env}-nat-eip-${index(local.target_azs, each.key) + 1}"
    resource = "vpc"
  }
}