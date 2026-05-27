resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(
    {
      Name = "${var.vpc_name_prefix}-${var.env}-internet-gateway"
    },
    var.extended_tags
  )
}