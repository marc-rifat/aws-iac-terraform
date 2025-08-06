data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.root}/${var.lambda_source_dir}"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "main" {
  function_name = "${var.project_name}-${var.environment}-lambda"
  role          = var.lambda_role_arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = 60

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      S3_BUCKET_NAME = var.s3_bucket_name
      ENVIRONMENT    = var.environment
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-lambda"
    Environment = var.environment
    Project     = var.project_name
  }
}


resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.main.function_name}"
  retention_in_days = 14

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}