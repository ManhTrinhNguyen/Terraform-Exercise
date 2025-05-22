resource "aws_vpc" "myapp-vpc" {
  cidr_block = var.cidr_block

  tags = {
    Name: "${var.env_prefix}-vpc"
  }
}

resource "aws_subnet" "myapp-subnet" {
  vpc_id     = aws_vpc.myapp-vpc.id
  cidr_block = var.subnet_cidr_block
  availability_zone = var.availability_zone

  tags = {
    Name = "${var.env_prefix}-subnet"
  }
}

resource "aws_route_table" "myapp-route-table" {
  vpc_id = aws_vpc.myapp-vpc.id

  route {
    cidr_block = "0.0.0.0/0" ## Destination . Any IP address can access to my VPC 
    gateway_id = aws_internet_gateway.myapp-igw.id ## This is a Internet Gateway for my Route Table 
  }

  tags = {
    Name = "${var.env_prefix}-rtb"
  }
}

resource "aws_internet_gateway" "myapp-igw" {
  vpc_id = aws_vpc.myapp-vpc.id

  tags = {
    Name = "${var.env_prefix}-rtb"
  }
}

resource "aws_route_table_association" "a-rtb-subnet" {
  route_table_id = aws_route_table.myapp-route-table.id
  subnet_id = aws_subnet.myapp-subnet.id
}

resource "aws_security_group" "myapp-sg" {
  name = "myapp-sg"
  description = "Allow inbound traffic and all outbound traffic"
  vpc_id = aws_vpc.myapp-vpc.id 
}

resource "aws_vpc_security_group_ingress_rule" "myapp-sg-ingress-ssh" {
  security_group_id = aws_security_group.myapp-sg.id 
  cidr_ipv4 = var.my_ip
  from_port = 22
  ip_protocol = "TCP"
  to_port = 22

  tags = {
    Name = "${var.env_prefix}-ingress-ssh"
  }
}

resource "aws_vpc_security_group_ingress_rule" "myapp-sg-ingress-8080" {
  security_group_id = aws_security_group.myapp-sg.id 
  cidr_ipv4 = "0.0.0.0/0"
  from_port = 8080
  ip_protocol = "TCP"
  to_port = 8080

  tags = {
    Name = "${var.env_prefix}-ingress-8080"
  }
}

resource "aws_vpc_security_group_egress_rule" "myapp-sg-egress" {
  security_group_id = aws_security_group.myapp-sg.id 
  cidr_ipv4 = "0.0.0.0/0"
  ip_protocol = "-1"

  tags = {
    Name = "${var.env_prefix}-egress"
  }
}

data "aws_ami" "amazon-linux-image" {

  owners = ["amazon"]
  most_recent = true 

  filter {
    name = "name"
    values =  ["al2023-ami-*-x86_64"]
  }

  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "myapp-1" {
  ami = data.aws_ami.amazon-linux-image.id
  instance_type = var.instance_type
  subnet_id = aws_subnet.myapp-subnet.id 
  vpc_security_group_ids = [aws_security_group.myapp-sg.id]
  availability_zone = var.availability_zone

  associate_public_ip_address = true

  key_name = "ansible"

  user_data_replace_on_change = true
  tags = {
    Name = "${var.env_prefix}-myapp-1"
  }
}


resource "aws_instance" "myapp-2" {
  ami = data.aws_ami.amazon-linux-image.id
  instance_type = var.instance_type
  subnet_id = aws_subnet.myapp-subnet.id 
  vpc_security_group_ids = [aws_security_group.myapp-sg.id]
  availability_zone = var.availability_zone

  associate_public_ip_address = true

  key_name = "ansible"

  user_data_replace_on_change = true
  tags = {
    Name = "${var.env_prefix}-myapp-2"
  }
}