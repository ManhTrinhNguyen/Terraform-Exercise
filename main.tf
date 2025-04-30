resource "aws_vpc" "myapp-vpc" {
  cidr_block = var.cidr_block

  tags = {
    Name: "${var.env_prefix}-vpc"
  }
}

module "myapp-subnet" {
  source = "./modules/subnet"
  vpc_id = aws_vpc.myapp-vpc.id
  subnet_cidr_block = var.subnet_cidr_block
  availability_zone = var.availability_zone
  env_prefix = var.env_prefix
}

module "myapp-webserver" {
  source = "./modules/webserver"
  vpc_id = aws_vpc.myapp-vpc.id
  subnet_id = module.myapp-subnet.subnet_id
  my_ip = var.my_ip
  env_prefix = var.env_prefix
  availability_zone = var.availability_zone
  image_name = var.image_name
  instance_type = var.instance_type
}
