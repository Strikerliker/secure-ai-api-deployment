output "api_base_url" {
  description = "Base URL for the deployed HTTP API."
  value       = aws_apigatewayv2_api.api.api_endpoint
}

output "health_url" {
  description = "Unauthenticated health endpoint."
  value       = "${aws_apigatewayv2_api.api.api_endpoint}/health"
}

output "generate_url" {
  description = "Protected AI generation endpoint."
  value       = "${aws_apigatewayv2_api.api.api_endpoint}/v1/generate"
}

output "api_token_secret_arn" {
  description = "Secrets Manager ARN whose value should be initialized out of band."
  value       = aws_secretsmanager_secret.api_token.arn
}

output "inference_lambda_name" {
  description = "Inference Lambda function name."
  value       = aws_lambda_function.inference.function_name
}

output "authorizer_lambda_name" {
  description = "Authorizer Lambda function name."
  value       = aws_lambda_function.authorizer.function_name
}
