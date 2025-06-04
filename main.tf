resource "aws_vpc" "myapp-vpc" {
  cidr_block = var.cidr_block

  enable_dns_hostnames = true

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

  # Using Local Exec 
  # provisioner "local-exec" { 
  #   working_dir = "../Ansible"
  #   command = "ansible-playbook --inventory ${self.public_ip}, --private-key ${var.ssh_private_key_location} --user ec2-user deploy-docker-new-user-with-Terraform.yaml"
  # }
  tags = {
    Name = "${var.env_prefix}-ansible"
  }
}

# resource "aws_instance" "myapp-2" {
#   ami = data.aws_ami.amazon-linux-image.id
#   instance_type = var.instance_type
#   subnet_id = aws_subnet.myapp-subnet.id 
#   vpc_security_group_ids = [aws_security_group.myapp-sg.id]
#   availability_zone = var.availability_zone

#   associate_public_ip_address = true

#   key_name = "ansible"

#   user_data_replace_on_change = true

#   # Using Local Exec 
#   # provisioner "local-exec" { 
#   #   working_dir = "../Ansible"
#   #   command = "ansible-playbook --inventory ${self.public_ip}, --private-key ${var.ssh_private_key_location} --user ec2-user deploy-docker-new-user-with-Terraform.yaml"
#   # }
#   tags = {
#     Name = "${var.env_prefix}-ansible"
#   }
# }


# resource "aws_instance" "myapp-3" {
#   ami = data.aws_ami.amazon-linux-image.id
#   instance_type = "t3.small"
#   subnet_id = aws_subnet.myapp-subnet.id 
#   vpc_security_group_ids = [aws_security_group.myapp-sg.id]
#   availability_zone = var.availability_zone


#   associate_public_ip_address = true

#   key_name = "ansible"

#   user_data_replace_on_change = true

  

#   # Using Local Exec 
#   # provisioner "local-exec" { 
#   #   working_dir = "../Ansible"
#   #   command = "ansible-playbook --inventory ${self.public_ip}, --private-key ${var.ssh_private_key_location} --user ec2-user deploy-docker-new-user-with-Terraform.yaml"
#   # }
#   tags = {
#     Name = "dev"
#   }
# }

# Using null_resource 
# resource "null_resource" "configure-server" {
#   triggers = {
#     trigger = aws_instance.myapp-1.public_ip
#   }

#   provisioner "local-exec" {
#     working_dir = "../Ansible"
#     command = "ansible-playbook --inventory ${aws_instance.myapp-1.public_ip}, --private-key ${var.ssh_private_key_location} --user ec2-user deploy-docker-new-user-with-Terraform.yaml"
#   }
# }