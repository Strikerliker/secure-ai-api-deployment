# Secure AI API Architecture

## Objective

Expose an Amazon Bedrock-backed AI capability through an API boundary that separates authentication, inference, secrets, and observability responsibilities.

## Request path

1. A client calls Amazon API Gateway.
2. `GET /health` is forwarded directly to the inference Lambda and never invokes Bedrock.
3. `POST /v1/generate` requires an `Authorization: Bearer ...` header.
4. API Gateway invokes the Lambda REQUEST authorizer.
5. The authorizer retrieves the expected token from AWS Secrets Manager and performs a constant-time comparison.
6. If authorized, API Gateway invokes the inference Lambda.
7. The inference Lambda validates the JSON payload and prompt length.
8. The Lambda invokes only the configured Amazon Bedrock foundation model.
9. The API returns a JSON response and writes operational telemetry to CloudWatch.

## Trust boundaries

### Internet to API Gateway

API Gateway is the public boundary. The stage applies throttling and only exposes the declared routes. Browser CORS origins are explicit and configurable.

### API Gateway to authorizer

The protected route uses a Lambda REQUEST authorizer. Authorization failures do not reach the inference function.

### Authorizer to Secrets Manager

The authorizer execution role can call `secretsmanager:GetSecretValue` only for the one API-token secret created for this project.

### API Gateway to inference Lambda

The inference function receives requests only through the API integration and has no permission to read the API token secret.

### Inference Lambda to Amazon Bedrock

The inference execution role can call `bedrock:InvokeModel` only for the configured foundation-model ARN. It does not receive broad administrator or wildcard service permissions.

## Security controls

- Secret value is not created in Terraform state
- No hardcoded AWS credentials or bearer token
- Constant-time bearer-token comparison
- Separate IAM roles for authorization and inference
- Least-privilege Bedrock model permission
- Prompt length validation before model invocation
- No-store response caching header
- API throttling
- Narrow CORS configuration
- CloudWatch API access logging without authorization headers or bodies
- Lambda execution logging with configurable retention
- Secrets Manager encryption at rest
- Terraform-based reproducibility
- CI unit tests, Bandit scanning, and Terraform validation

## Production expansion path

A production system could replace the shared bearer token with Amazon Cognito or an external OIDC/JWT identity provider, add AWS WAF, private API connectivity, KMS customer-managed keys, request/response content filtering, Bedrock Guardrails, structured audit events, distributed tracing, alarms, cost controls, canary releases, and automated secret rotation.
