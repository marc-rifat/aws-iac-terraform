variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "api_gateway_domain" {
  description = "Domain name of the API Gateway"
  type        = string
}

variable "api_gateway_url" {
  description = "Full URL of the API Gateway"
  type        = string
}

variable "frontend_source_dir" {
  description = "Path to the frontend source code directory"
  type        = string
  default     = "../../../frontend"
}