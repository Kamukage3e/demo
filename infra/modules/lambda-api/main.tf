resource "aws_iam_role" "lambda_exec" {
  name = "${var.lambda_name}_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Effect = "Allow",
      Sid    = ""
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "lambda" {
  function_name    = var.lambda_name
  filename         = var.lambda_zip_path
  handler          = var.lambda_handler
  runtime          = "provided.al2023"
  role             = aws_iam_role.lambda_exec.arn
  source_code_hash = try(filebase64sha256(var.lambda_zip_path), "")
  timeout          = 30

  environment {
    variables = {
      ENVIRONMENT = var.stage
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.lambda_name}"
  retention_in_days = 14
}

resource "aws_api_gateway_rest_api" "api" {
  name        = "${var.lambda_name}-api"
  description = "API Gateway for ${var.lambda_name}"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy_any" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

# Handle root path
resource "aws_api_gateway_method" "root_any" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_rest_api.api.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_proxy" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = aws_api_gateway_method.proxy_any.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda.invoke_arn
}

resource "aws_api_gateway_integration" "lambda_root" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_rest_api.api.root_resource_id
  http_method             = aws_api_gateway_method.root_any.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda.invoke_arn
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [
    aws_api_gateway_integration.lambda_proxy,
    aws_api_gateway_integration.lambda_root
  ]

  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = var.stage

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.proxy.id,
      aws_api_gateway_method.proxy_any.id,
      aws_api_gateway_method.root_any.id,
      aws_api_gateway_integration.lambda_proxy.id,
      aws_api_gateway_integration.lambda_root.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

output "api_url" {
  description = "Base URL for API Gateway stage"
  value       = "https://${aws_api_gateway_rest_api.api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${var.stage}"
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.lambda.function_name
}

variable "lambda_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "lambda_zip_path" {
  description = "Path to the Lambda deployment package"
  type        = string
}

variable "lambda_handler" {
  description = "Lambda function entrypoint"
  type        = string
}

variable "stage" {
  description = "Deployment stage"
  type        = string
}

# Add data source to get current region
data "aws_region" "current" {}
