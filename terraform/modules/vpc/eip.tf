# Elastic IPs for NAT Gateways

# Elastic IPs for NAT Gateways (based on the number of nat_gateway_count variable)
resource "aws_eip" "nat" {
  for_each = {
    for index, az in local.nat_azs :
    az => {
      index = index
      az    = az
    }
  }

  domain = "vpc"

  tags = merge(
    {
      Name = "${var.vpc_name_prefix}-${var.env}-nat-eip-${each.value.index + 1}"
    },
    var.extended_tags
  )
}