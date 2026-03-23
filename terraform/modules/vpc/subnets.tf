resource "aws_subnet" "public_subnet_1" {
  vpc_id = aws_vpc.main_vpc.id
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block = "10.0.1.0/24"
  tags = {
    Tier = "public"
    resource = "vpc"
    Name = "${var.env}-${var.app}-public-subnet-1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id = aws_vpc.main_vpc.id
  availability_zone = data.aws_availability_zones.available.names[1]
  cidr_block = "10.0.2.0/24"
  tags = {
    Tier = "public"
    resource = "vpc"
    Name = "${var.env}-${var.app}-public-subnet-2"
  }
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id = aws_vpc.main_vpc.id
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block = "10.0.11.0/24"
  tags = {
    Tier = "private"
    resource = "vpc"
    Name = "${var.env}-${var.app}-private-subnet-1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id = aws_vpc.main_vpc.id
  availability_zone = data.aws_availability_zones.available.names[1]
  cidr_block = "10.0.12.0/24"
  tags = {
    Tier = "private"
    resource = "vpc"
    Name = "${var.env}-${var.app}-private-subnet-2"
  }
}
