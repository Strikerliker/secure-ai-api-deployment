# Secure AI API Deployment

A production-style AWS portfolio project that demonstrates how to expose a generative AI workload through a controlled API layer without storing long-lived credentials or application secrets in source code.

The reference architecture uses Amazon API Gateway, AWS Lambda, AWS Secrets Manager, Amazon Bedrock, CloudWatch, IAM, and Terraform. A dedicated Lambda authorizer protects the inference route with a bearer token stored in Secrets Manager, while the inference Lambda has only the permissions it needs to invoke the configured Bedrock model.

## What this project demonstrates

- Amazon API Gateway HTTP API with explicit routes
- Public health endpoint and protected AI inference endpoint
- Lambda REQUEST authorizer with constant-time token comparison
- API token stored in AWS Secrets Manager instead of source code
- Least-privilege IAM separation between authorization and inference functions
- Amazon Bedrock model invocation from Lambda
- Request size and prompt-length validation
- API throttling and structured access logging
- CloudWatch log retention for API and Lambda telemetry
- Terraform infrastructure as code
- Python unit tests and Bandit security scanning
- GitHub Actions validation
- Portfolio dashboard with live CI status

## Architecture

```text
Client
  |
  v
Amazon API Gateway
  |-------------------------------> GET /health
  |
  +--> POST /v1/generate
          |
          v
   Lambda Authorizer
          |
          +--> AWS Secrets Manager
          |      bearer token
          |
       authorized?
          |
          v
     Inference Lambda
          |
          v
     Amazon Bedrock
          |
          v
     JSON response

CloudWatch receives API access logs and Lambda execution logs.
```

## Repository contents

- `src/app.py` — API request validation and Bedrock inference handler
- `src/authorizer.py` — bearer-token Lambda authorizer
- `tests/` — unit tests for validation and authorization helpers
- `terraform/` — API Gateway, Lambda, IAM, Secrets Manager, and CloudWatch infrastructure
- `docs/architecture.md` — security architecture and trust boundaries
- `docs/deployment.md` — deployment and secret-initialization procedure
- `dashboard.html` — project dashboard with live GitHub Actions status
- `.github/workflows/validate.yml` — Python, Bandit, and Terraform validation

## API routes

### `GET /health`

Returns service status and does not invoke Bedrock.

### `POST /v1/generate`

Requires:

```text
Authorization: Bearer <token stored in Secrets Manager>
Content-Type: application/json
```

Example request body:

```json
{
  "prompt": "Summarize the security benefits of short-lived cloud credentials."
}
```

The handler rejects empty prompts and prompts longer than the configured limit before invoking the model.

## Deploy

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Terraform creates the Secrets Manager secret container but intentionally does **not** create the secret value in Terraform state. After deployment, initialize the token out of band:

```bash
aws secretsmanager put-secret-value \
  --secret-id "$(terraform output -raw api_token_secret_arn)" \
  --secret-string "REPLACE_WITH_A_LONG_RANDOM_TOKEN"
```

Then call the protected endpoint using the API URL from Terraform output.

## Security notes

- No API token is committed to GitHub.
- The authorizer role can read only the configured secret.
- The inference role can invoke only the configured Bedrock foundation model ARN.
- API Gateway applies route authorization and stage throttling.
- CORS is intentionally narrow and configurable rather than open by default.
- CloudWatch access logging excludes request bodies and bearer tokens.
- The Secrets Manager value should be rotated according to the operator's security policy.

## Portfolio note

This repository is a reproducible reference implementation. Terraform validation and application tests can run without deploying cloud resources. `terraform apply` creates AWS resources and may incur charges. The project does not claim a live production deployment unless the operator explicitly deploys and verifies it in an AWS account.
