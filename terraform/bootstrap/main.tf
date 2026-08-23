# Tell Terraform which providers it needs and where to get them
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"   # the official AWS provider, downloaded from the Terraform registry
      version = "~> 5.0"          # use any 5.x version (~> means "5.x but not 6.0") — pins for reproducibility
    }
  }
}

# Configure the AWS provider — tells Terraform which region to create resources in
provider "aws" {
  region = "eu-west-1"            # pick a region close to you (eu-west-1 = Ireland); all resources land here
}

# Create the S3 bucket that will hold your MAIN config's state file
resource "aws_s3_bucket" "tf_state" {
  bucket = "danielodriscoll-devops-portfolio-tfstate"   # MUST be globally unique across all of AWS — change if taken

  tags = {
    Name    = "terraform-state"    # human-readable label, shows in the console
    Project = "devops-portfolio"   # groups this resource with the project
  }
}

# Turn on versioning — keeps a history of the state file so you can recover if it's corrupted or bad-applied
resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id   # references the bucket created above (Terraform figures out the dependency order)

  versioning_configuration {
    status = "Enabled"                 # every change to the state file keeps the old version too
  }
}

# Block all public access to the state bucket — state can contain sensitive values, must never be public
resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true       # ignore any attempt to make objects public via ACLs
  block_public_policy     = true       # reject any bucket policy that would grant public access
  ignore_public_acls      = true       # ignore existing public ACLs
  restrict_public_buckets = true       # extra lockdown — only the account owner can access
}

# Encrypt the state file at rest — again, because state can hold secrets
resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"         # AWS-managed encryption, free, no key setup needed
    }
  }
}