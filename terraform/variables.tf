variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "iac-test"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket to be created by Lambda"
  type        = string
  default     = "iac-testing-440225444492340"
}

variable "lambda_source_dir" {
  description = "Path to Lambda source code directory"
  type        = string
  default     = "../lambda"
}

variable "frontend_source_dir" {
  description = "Path to frontend source code directory"
  type        = string
  default     = "../frontend"
}

variable "backend_source_dir" {
  description = "Path to backend source code directory"
  type        = string
  default     = "../backend"
}