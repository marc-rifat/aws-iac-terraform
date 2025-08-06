# API Gateway REST API
resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.project_name}-${var.environment}-api"
  description = "API Gateway for ${var.project_name} ${var.environment}"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-api"
    Environment = var.environment
    Project     = var.project_name
  }
}

# API Gateway Resource
resource "aws_api_gateway_resource" "lambda" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "test-lambda"
}

# API Gateway Method
resource "aws_api_gateway_method" "lambda_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.lambda.id
  http_method   = "POST"
  authorization = "NONE"
}

# API Gateway Method - OPTIONS for CORS
resource "aws_api_gateway_method" "lambda_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.lambda.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# API Gateway Integration for POST
resource "aws_api_gateway_integration" "lambda_post" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.lambda.id
  http_method = aws_api_gateway_method.lambda_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_arn
}

# API Gateway Integration for OPTIONS (CORS)
resource "aws_api_gateway_integration" "lambda_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.lambda.id
  http_method = aws_api_gateway_method.lambda_options.http_method

  type = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# API Gateway Method Response for POST
resource "aws_api_gateway_method_response" "lambda_post_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.lambda.id
  http_method = aws_api_gateway_method.lambda_post.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# API Gateway Method Response for OPTIONS (CORS)
resource "aws_api_gateway_method_response" "lambda_options_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.lambda.id
  http_method = aws_api_gateway_method.lambda_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

# API Gateway Integration Response for POST
resource "aws_api_gateway_integration_response" "lambda_post" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.lambda.id
  http_method = aws_api_gateway_method.lambda_post.http_method
  status_code = aws_api_gateway_method_response.lambda_post_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  depends_on = [aws_api_gateway_integration.lambda_post]
}

# API Gateway Integration Response for OPTIONS (CORS)
resource "aws_api_gateway_integration_response" "lambda_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.lambda.id
  http_method = aws_api_gateway_method.lambda_options.http_method
  status_code = aws_api_gateway_method_response.lambda_options_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.lambda_options]
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway-${var.project_name}-${var.environment}"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "main" {
  depends_on = [
    aws_api_gateway_method.lambda_post,
    aws_api_gateway_method.lambda_options,
    aws_api_gateway_integration.lambda_post,
    aws_api_gateway_integration.lambda_options,
  ]

  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.lambda.id,
      aws_api_gateway_method.lambda_post.id,
      aws_api_gateway_method.lambda_options.id,
      aws_api_gateway_integration.lambda_post.id,
      aws_api_gateway_integration.lambda_options.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Stage
resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.environment

  tags = {
    Name        = "${var.project_name}-${var.environment}-api-stage"
    Environment = var.environment
    Project     = var.project_name
  }
}