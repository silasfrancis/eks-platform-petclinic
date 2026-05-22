resource "aws_eip" "nat_eip_1" {
  domain = "vpc"
  tags = {
    resource = "vpc"
    Name = "${var.app}-${var.env}-nat-eip-1"
  }
}

resource "aws_eip" "nat_eip_2" {
  domain = "vpc"
  tags = {
    resource = "vpc"
    Name = "${var.app}-${var.env}-nat-eip-2"
  }
}
