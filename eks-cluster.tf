variable "instance_types" {}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.35.0"

  cluster_name = "myapp-eks"
  cluster_version = "1.32"

  cluster_endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  subnet_ids = module.vpc.private_subnets
  vpc_id = module.vpc.vpc_id

  eks_managed_node_groups = {
    example = {
      # Starting on 1.30, AL2023 is the default AMI type for EKS managed node groups
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = [var.instance_types]

      min_size     = 2
      max_size     = 5
      desired_size = 2
    }
  }

  tags = {
    evironment = "dev"
    application = "myapp"
  } 
}