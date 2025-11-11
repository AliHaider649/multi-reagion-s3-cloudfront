terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ================================
# VARIABLES
# ================================
variable "project_name" {
  type        = string
  description = "Project name used in bucket and distribution names"
  default     = "multi-region-project"
}

variable "environment" {
  type        = string
  description = "Environment tag"
  default     = "dev"
}

variable "primary_region" {
  type        = string
  description = "Primary AWS region"
  default     = "us-east-1"
}

variable "secondary_region" {
  type        = string
  description = "Secondary AWS region"
  default     = "us-west-2"
}
# ================================
# PROVIDERS
# ================================
provider "aws" {
  region = var.primary_region
}

provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
}

# ================================
# PRIMARY S3 BUCKET
# ================================
resource "aws_s3_bucket" "primary" {
  bucket = "${var.project_name}-primary-${var.primary_region}"

  tags = {
    Name = "${var.project_name}-primary"
    Env  = var.environment
  }
}

resource "aws_s3_bucket_versioning" "primary" {
  bucket = aws_s3_bucket.primary.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "primary" {
  bucket = aws_s3_bucket.primary.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ================================
# SECONDARY S3 BUCKET
# ================================
resource "aws_s3_bucket" "secondary" {
  provider = aws.secondary
  bucket   = "${var.project_name}-secondary-${var.secondary_region}"

  tags = {
    Name = "${var.project_name}-secondary"
    Env  = var.environment
  }
}

resource "aws_s3_bucket_versioning" "secondary" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.secondary.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "secondary" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.secondary.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ================================
# CLOUD FRONT ORIGIN ACCESS IDENTITY
# ================================
resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI for ${var.project_name}-cdn"
}

# ================================
# CLOUD FRONT DISTRIBUTION
# ================================
resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name = aws_s3_bucket.primary.bucket_regional_domain_name
    origin_id   = "primary-s3-origin"

    s3_origin_config {
      origin_access_identity = "origin-access-identity/cloudfront/${aws_cloudfront_origin_access_identity.oai.id}"
    }
  }

  default_cache_behavior {
    target_origin_id       = "primary-s3-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "${var.project_name}-cdn"
    Env  = var.environment
  }
}

# ================================
# S3 BUCKET POLICY TO ALLOW CLOUD FRONT OAI
# ================================
resource "aws_s3_bucket_policy" "primary_policy" {
  bucket = aws_s3_bucket.primary.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.oai.iam_arn
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.primary.arn}/*"
      }
    ]
  })
}

# ================================
# OUTPUTS
# ================================
output "primary_bucket_name" {
  value = aws_s3_bucket.primary.bucket
}

output "secondary_bucket_name" {
  value = aws_s3_bucket.secondary.bucket
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.cdn.domain_name
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.cdn.id
}
