resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

//public subnet
resource "aws_subnet" "public_sub_1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_subnet_cidrs[0]
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "kubernetes.io/role/elb"                    = "1"
  }
}

resource "aws_subnet" "public_sub_2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_subnet_cidrs[1] # Đảm bảo bạn khai báo thêm cidr thứ 2 trong file variables
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "kubernetes.io/role/elb"                    = "1"
  }
}

resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "association" {
  route_table_id = aws_route_table.route_table.id
  subnet_id      = aws_subnet.public_sub_1.id

}

resource "aws_route_table_association" "association_pub2" {
  route_table_id = aws_route_table.route_table.id
  subnet_id      = aws_subnet.public_sub_2.id
}

//private subnet
resource "aws_subnet" "private_sub_1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.private_subnet_cidrs[0]
  availability_zone = "${var.aws_region}a"
  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "kubernetes.io/role/internal-elb"           = "1"
  }
}

resource "aws_route_table" "route_table_private" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route_table_association" "association_private" {
  route_table_id = aws_route_table.route_table_private.id
  subnet_id      = aws_subnet.private_sub_1.id
}
