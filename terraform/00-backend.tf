# S3 bucket for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  bucket = "my-terraform-state-bucket-${random_id.bucket_suffix.hex}"
  acl    = "private"

  versioning {
    enabled = true
  }

  force_destroy = true
}

resource "random_id" "bucket_suffix" {
  byte_length = 8
}

# Terraform Backend Configuration
terraform {
  backend "s3" {
    bucket = aws_s3_bucket.terraform_state.bucket
    key    = "state"
    region = "eu-west-2"
  }
}

# Ensure to output the S3 bucket name
output "s3_bucket_name" {
  value = aws_s3_bucket.terraform_state.bucket
}
