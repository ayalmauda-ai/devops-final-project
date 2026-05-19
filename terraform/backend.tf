# terraform/backend.tf
# Stores Terraform state in S3 with DynamoDB locking.
# The state file is Terraform's memory of every resource it has created.
# Keeping it in S3 (not on your laptop) lets Jenkins read it during deployments.

terraform {
  backend "s3" {
    bucket         = "ayal-tfstate-devops-final"
    key            = "devops-final/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tfstate-lock"
    encrypt        = true
  }
}
