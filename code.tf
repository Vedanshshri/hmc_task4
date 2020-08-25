provider "aws" {
  region     = "ap-south-1"
  profile = "special"

}


resource "aws_vpc" "ved_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "ved_vpc"
  }
}


resource "aws_subnet" "public_subnet" {
  vpc_id     = "${aws_vpc.ved_vpc.id}"
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = "true"
  tags = {
    Name = "public_subnet"
  }
  depends_on = [ aws_vpc.ved_vpc, ]

}

resource "aws_subnet" "private_subnet" {
  vpc_id     = "${aws_vpc.ved_vpc.id}"
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-south-1a"
  tags = {
    Name = "private_subnet"
  }
  depends_on = [ aws_vpc.ved_vpc, ]
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = "${aws_vpc.ved_vpc.id}"
  tags = {
    Name = "internet_gateway"
  }

  depends_on = [ aws_vpc.ved_vpc, ]
}

resource "aws_route_table" "route_table" {
  vpc_id = "${aws_vpc.ved_vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.internet_gateway.id}"
  }
  tags = {
    Name = "route_table"
  }
  depends_on = [ aws_internet_gateway.internet_gateway, ]
}
resource "aws_route_table_association" "association_routing_table" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.route_table.id
  depends_on = [ aws_route_table.route_table, ]

}


resource "aws_eip" "lb" {
  vpc      = true
  depends_on = [ aws_vpc.ved_vpc, ]
}


resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = "${aws_eip.lb.id}"
  subnet_id     = "${aws_subnet.private_subnet.id}"

  tags = {
    Name = "gw NAT"
  }
  depends_on = [ aws_vpc.ved_vpc, aws_eip.lb ]
}


resource "aws_route_table" "route_table_nat_gateway" {
  vpc_id = "${aws_vpc.ved_vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.nat_gateway.id}"
  }
  tags = {
    Name = "route_table"
  }
  depends_on = [ aws_nat_gateway.nat_gateway, ]
}

resource "aws_route_table_association" "association_routing_table_nat_gateway" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.route_table_nat_gateway.id
  depends_on = [ aws_route_table.route_table_nat_gateway, ]

}

resource "aws_security_group" "wordpress" {
  name        = "wordpress"
  description = "To connect with wordpress os"
  vpc_id      = "${aws_vpc.ved_vpc.id}"


  ingress {
    description = "Http from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = "sgroup_wordpress"
  }

  depends_on = [ aws_vpc.ved_vpc, ]
}

resource "aws_security_group" "mysql" {
  name        = "for-mysql"
  description = "connect to mysql instance"
  vpc_id      = "${aws_vpc.ved_vpc.id}"


  ingress {
    description = "MYSQL from VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = "sgroup_mysql"
  }
  depends_on = [ aws_vpc.ved_vpc, ]
}

resource "tls_private_key" "private_key" { 
  algorithm   = "RSA"
  rsa_bits = "2048"
}


resource "aws_key_pair" "task-3-key" {
  depends_on = [ tls_private_key.private_key, ]
  key_name   = "dev-key"
  public_key = tls_private_key.private_key.public_key_openssh
}

resource "aws_instance" "wordpress" {
  ami           = "ami-7e257211"
  instance_type = "t2.micro"
  key_name      = "dev-key"
  availability_zone = "ap-south-1a"
  subnet_id     = "${aws_subnet.public_subnet.id}"
  security_groups = [ "${aws_security_group.wordpress.id}" ]
  tags = {
    Name = "Wordpress"
  }
  depends_on = [ aws_subnet.public_subnet, ]
}

resource "aws_instance" "mysql" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name      = "dev-key"
  availability_zone = "ap-south-1a"
  subnet_id     = "${aws_subnet.private_subnet.id}"
  security_groups = [ "${aws_security_group.mysql.id}" ]
  tags = {
    Name = "MYSQL"
  }
  depends_on = [ aws_subnet.private_subnet, ]
}
