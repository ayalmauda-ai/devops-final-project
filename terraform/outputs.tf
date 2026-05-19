# terraform/outputs.tf
# Values printed after `terraform apply`.
# Ansible reads them with: terraform output -raw cluster_name

output "cluster_name" {
  description = "EKS cluster name — used by Ansible and the CD pipeline."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "HTTPS URL of the EKS API server."
  value       = module.eks.cluster_endpoint
}

output "region" {
  description = "AWS region where the cluster lives."
  value       = var.aws_region
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded CA certificate for kubectl."
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for IAM IRSA (Phase 8)."
  value       = module.eks.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN for attaching IAM policies to service accounts."
  value       = module.eks.oidc_provider_arn
}
