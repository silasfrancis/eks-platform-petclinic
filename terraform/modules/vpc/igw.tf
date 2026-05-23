resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name     = "${var.app}-${var.env}-internet-gateway"
    resource = "vpc"
  }
}