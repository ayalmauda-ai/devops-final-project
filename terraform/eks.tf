# terraform/eks.tf
# EKS cluster + managed node group.
# Worker nodes go into private subnets (unreachable from internet directly).
# enable_cluster_creator_admin_permissions lets you run kubectl immediately
# after apply without any manual aws-auth ConfigMap editing.

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    main = {
      instance_types = [var.node_instance_type]
      desired_size   = var.node_desired_size
      min_size       = var.node_min_size
      max_size       = var.node_max_size
    }
  }

  enable_cluster_creator_admin_permissions = true

  tags = {
    Project     = "devops-final"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
