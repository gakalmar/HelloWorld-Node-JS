provider "aws" {
  region = "eu-west-2"
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "terraform-backend-bucket-hw-app-gk-240617"
  acl    = "private"

  versioning {
    enabled = true
  }

  force_destroy = true
}

output "bucket_name" {
  value = aws_s3_bucket.terraform_state.bucket
}
