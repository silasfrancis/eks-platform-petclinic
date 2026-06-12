# NAT Gateways
#
# One NAT gateway per AZ in nat_azs (controlled by var.nat_gateway_count),
# placed in the public subnet of the corresponding AZ. dev uses 1 (single
# egress path, cheaper); prod uses 2 (one per AZ, for resilience).


# NAT Gateways (placed dynamically inside a public subnet depending on the nat_gateway_count and corresponding public_subnet_count variable)
resource "aws_nat_gateway" "nat" {
  for_each = {
    for index, az in local.nat_azs :
    az => {
      index = index
      az    = az
    }
  }

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = merge(
    {
      Name = "${var.vpc_name_prefix}-${var.env}-nat-gateway-${each.value.index + 1}"
    },
    var.extended_tags
  )

  depends_on = [
    aws_internet_gateway.igw
  ]
}