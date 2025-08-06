terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# IAM roles and policies
module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
  environment  = var.environment
}

# Lambda function
module "lambda" {
  source = "./modules/lambda"

  project_name      = var.project_name
  environment       = var.environment
  lambda_role_arn   = module.iam.lambda_execution_role_arn
  s3_bucket_name    = var.s3_bucket_name
  lambda_source_dir = var.lambda_source_dir
}

# API Gateway
module "api_gateway" {
  source = "./modules/api-gateway"

  project_name         = var.project_name
  environment          = var.environment
  lambda_arn           = module.lambda.lambda_invoke_arn
  lambda_function_name = module.lambda.lambda_function_name
}

# ECS for Spring Boot backend
module "ecs" {
  source = "./modules/ecs"

  project_name                = var.project_name
  environment                 = var.environment
  lambda_function_name        = module.lambda.lambda_function_name
  aws_region                  = var.aws_region
  ecs_task_execution_role_arn = module.iam.ecs_task_execution_role_arn
  ecs_task_role_arn           = module.iam.ecs_task_role_arn
  backend_source_dir          = var.backend_source_dir
}

# CloudFront and S3 for Angular frontend
module "cloudfront" {
  source = "./modules/cloudfront"

  project_name        = var.project_name
  environment         = var.environment
  api_gateway_domain  = module.api_gateway.api_gateway_domain
  api_gateway_url     = module.api_gateway.api_gateway_url
  frontend_source_dir = var.frontend_source_dir
}