data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Portfolio   = "John-D"
    },
    var.tags
  )
  bedrock_model_arn = "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.name}::foundation-model/${var.bedrock_model_id}"
}

resource "aws_secretsmanager_secret" "api_token" {
  name                    = "${local.name_prefix}-bearer-token"
  description             = "Bearer token used by the Secure AI API Lambda authorizer."
  recovery_window_in_days = 7
  tags                    = local.common_tags
}

data "archive_file" "lambda_package" {
  type        = "zip"
  source_dir  = "${path.module}/../src"
  output_path = "${path.module}/secure-ai-api.zip"
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "authorizer" {
  name               = "${local.name_prefix}-authorizer-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = local.common_tags
}

resource "aws_iam_role" "inference" {
  name               = "${local.name_prefix}-inference-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "authorizer_logs" {
  role       = aws_iam_role.authorizer.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "inference_logs" {
  role       = aws_iam_role.inference.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "authorizer" {
  statement {
    sid       = "ReadOnlyApiToken"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.api_token.arn]
  }
}

resource "aws_iam_role_policy" "authorizer" {
  name   = "${local.name_prefix}-authorizer-policy"
  role   = aws_iam_role.authorizer.id
  policy = data.aws_iam_policy_document.authorizer.json
}

data "aws_iam_policy_document" "inference" {
  statement {
    sid       = "InvokeConfiguredBedrockModel"
    effect    = "Allow"
    actions   = ["bedrock:InvokeModel"]
    resources = [local.bedrock_model_arn]
  }
}

resource "aws_iam_role_policy" "inference" {
  name   = "${local.name_prefix}-inference-policy"
  role   = aws_iam_role.inference.id
  policy = data.aws_iam_policy_document.inference.json
}

resource "aws_cloudwatch_log_group" "authorizer" {
  name              = "/aws/lambda/${local.name_prefix}-authorizer"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "inference" {
  name              = "/aws/lambda/${local.name_prefix}-inference"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/apigateway/${local.name_prefix}"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_lambda_function" "authorizer" {
  function_name = "${local.name_prefix}-authorizer"
  description   = "Validates bearer tokens against AWS Secrets Manager."
  role          = aws_iam_role.authorizer.arn
  runtime       = "python3.12"
  handler       = "authorizer.lambda_handler"
  timeout       = 10
  memory_size   = 256

  filename         = data.archive_file.lambda_package.output_path
  source_code_hash = data.archive_file.lambda_package.output_base64sha256

  environment {
    variables = {
      API_TOKEN_SECRET_ARN = aws_secretsmanager_secret.api_token.arn
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.authorizer,
    aws_iam_role_policy.authorizer,
    aws_iam_role_policy_attachment.authorizer_logs
  ]

  tags = local.common_tags
}

resource "aws_lambda_function" "inference" {
  function_name = "${local.name_prefix}-inference"
  description   = "Validates requests and invokes the configured Amazon Bedrock model."
  role          = aws_iam_role.inference.arn
  runtime       = "python3.12"
  handler       = "app.lambda_handler"
  timeout       = 60
  memory_size   = 512

  filename         = data.archive_file.lambda_package.output_path
  source_code_hash = data.archive_file.lambda_package.output_base64sha256

  environment {
    variables = {
      MODEL_ID         = var.bedrock_model_id
      MAX_PROMPT_CHARS = tostring(var.max_prompt_chars)
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.inference,
    aws_iam_role_policy.inference,
    aws_iam_role_policy_attachment.inference_logs
  ]

  tags = local.common_tags
}

resource "aws_apigatewayv2_api" "api" {
  name          = local.name_prefix
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = var.allowed_origins
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["authorization", "content-type"]
    max_age       = 300
  }

  tags = local.common_tags
}

resource "aws_apigatewayv2_integration" "inference" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.inference.invoke_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 30000
}

resource "aws_apigatewayv2_authorizer" "token" {
  api_id                            = aws_apigatewayv2_api.api.id
  name                              = "${local.name_prefix}-token-authorizer"
  authorizer_type                   = "REQUEST"
  authorizer_uri                    = aws_lambda_function.authorizer.invoke_arn
  identity_sources                  = ["$request.header.Authorization"]
  authorizer_payload_format_version = "2.0"
  enable_simple_responses           = true
  authorizer_result_ttl_in_seconds  = 0
}

resource "aws_apigatewayv2_route" "health" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.inference.id}"
}

resource "aws_apigatewayv2_route" "generate" {
  api_id             = aws_apigatewayv2_api.api.id
  route_key          = "POST /v1/generate"
  target             = "integrations/${aws_apigatewayv2_integration.inference.id}"
  authorization_type = "CUSTOM"
  authorizer_id      = aws_apigatewayv2_authorizer.token.id
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = var.throttling_burst_limit
    throttling_rate_limit  = var.throttling_rate_limit
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api.arn
    format = jsonencode({
      requestId        = "$context.requestId"
      routeKey         = "$context.routeKey"
      status           = "$context.status"
      responseLength   = "$context.responseLength"
      integrationError = "$context.integrationErrorMessage"
      sourceIp         = "$context.identity.sourceIp"
    })
  }

  tags = local.common_tags
}

resource "aws_lambda_permission" "api_inference" {
  statement_id  = "AllowApiGatewayInvokeInference"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.inference.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_authorizer" {
  statement_id  = "AllowApiGatewayInvokeAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.authorizer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/authorizers/${aws_apigatewayv2_authorizer.token.id}"
}
