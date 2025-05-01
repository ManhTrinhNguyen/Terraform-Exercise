variable "vpc_cidr_block" {}
variable "private_subnets_cidr_blocks" {}
variable "public_subnets_cidr_blocks" {}

data "aws_availability_zones" "azs" {} # data belong to a provider so I have to specify the Provider .

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "5.19.0"

  name = "my-vpc"
  cidr = var.vpc_cidr_block

  private_subnets = var.private_subnets_cidr_blocks
  public_subnets  = var.public_subnets_cidr_blocks
  azs = data.aws_availability_zones.azs.names

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_dns_hostnames = true 

  tags = {
  "kubernetes.io/cluster/myapp-eks" = "shared" # This will be a cluster name
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/myapp-eks" = "shared"
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/myapp-eks" = "shared"
    "kubernetes.io/role/internal-elb" = 1
  }
}