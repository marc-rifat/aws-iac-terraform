# S3 bucket for frontend hosting
resource "aws_s3_bucket" "frontend" {
  bucket        = "${var.project_name}-${var.environment}-frontend"
  force_destroy = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-frontend"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudFront Origin Access Control
resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${var.project_name}-${var.environment}-frontend-oac"
  description                       = "Origin Access Control for S3 frontend bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "frontend" {
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
    origin_id                = "S3-${aws_s3_bucket.frontend.bucket}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project_name} ${var.environment} frontend distribution"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.frontend.bucket}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
  }

  # Cache behavior for API calls (proxy to backend)
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "API-${var.project_name}-${var.environment}"

    forwarded_values {
      query_string = true
      headers      = ["*"]
      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
    compress               = true
  }

  # Additional origin for API Gateway
  origin {
    domain_name = var.api_gateway_domain
    origin_id   = "API-${var.project_name}-${var.environment}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-frontend-cdn"
    Environment = var.environment
    Project     = var.project_name
  }
}

# S3 bucket policy for CloudFront
resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.frontend.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
          }
        }
      }
    ]
  })
}

# Null resource to handle frontend deployment
resource "null_resource" "frontend_deployment" {
  depends_on = [
    aws_s3_bucket.frontend,
    aws_s3_bucket_policy.frontend,
    aws_cloudfront_distribution.frontend
  ]

  # Triggers for when to redeploy
  triggers = {
    bucket_id       = aws_s3_bucket.frontend.id
    api_gateway_url = var.api_gateway_url
  }

  # Build and deploy Angular frontend
  provisioner "local-exec" {
    command = <<-EOT
      cd ${var.frontend_source_dir}
      
      # Install dependencies if package.json changed or node_modules doesn't exist
      if [ ! -d "node_modules" ] || [ "package.json" -nt "node_modules" ]; then
        echo "Installing Node.js dependencies..."
        npm install
      fi

      # Update config.json with current API Gateway URL
      if [ -n "${var.api_gateway_url}" ]; then
        echo "Updating config.json with API URL: ${var.api_gateway_url}"
        
        # Create the config.json file with the current API Gateway URL
        cat > src/assets/config.json << EOF
{
  "apiUrl": "${var.api_gateway_url}"
}
EOF
        
        echo "Generated config.json:"
        cat src/assets/config.json
      fi

      # Build for production
      echo "Building Angular application for production..."
      npm run build:prod

      # Deploy to S3
      echo "Deploying to S3 bucket: ${aws_s3_bucket.frontend.bucket}"
      aws s3 sync dist/iac-test-frontend/ s3://${aws_s3_bucket.frontend.bucket} --delete

      # No need to restore files since we're using dynamic config.json
    EOT

    interpreter = ["bash", "-c"]
  }

  # Invalidate CloudFront cache after deployment
  provisioner "local-exec" {
    command     = "aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.frontend.id} --paths '/*'"
    interpreter = ["bash", "-c"]
  }

  # Cleanup on destroy
  provisioner "local-exec" {
    when        = destroy
    command     = "aws s3 rm s3://${self.triggers.bucket_id} --recursive || true"
    interpreter = ["bash", "-c"]
  }
}