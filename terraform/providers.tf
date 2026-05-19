# terraform/providers.tf
# Declares which provider plugins are needed and where to download them.
# "~> 5.0" means "5.x but not 6.x" — bug fixes only, no breaking changes.

terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

# Reads credentials from ~/.aws/credentials locally, or from the
# AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY env vars set by Jenkins.
provider "aws" {
  region = var.aws_region
}
