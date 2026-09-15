# Deployment Guide

## Prerequisites

- AWS CLI authenticated to a non-production account for testing
- Terraform 1.6+
- Access to the configured Amazon Bedrock model in the selected Region
- Permission to create API Gateway, Lambda, IAM, CloudWatch, and Secrets Manager resources

## 1. Initialize and review Terraform

```bash
cd terraform
terraform init
terraform fmt -recursive
terraform validate
terraform plan
```

Review the plan before applying because the stack creates billable AWS resources.

## 2. Deploy

```bash
terraform apply
```

Record these outputs:

```bash
terraform output api_base_url
terraform output health_url
terraform output generate_url
terraform output api_token_secret_arn
```

## 3. Initialize the API token

Terraform creates only the Secrets Manager secret container so the secret value is not written into Terraform state.

Generate a strong random token using an approved password or secrets tool, then write it to Secrets Manager:

```bash
aws secretsmanager put-secret-value \
  --secret-id "$(terraform output -raw api_token_secret_arn)" \
  --secret-string "REPLACE_WITH_A_LONG_RANDOM_TOKEN"
```

Do not commit the token to source control or place it in Terraform variables.

## 4. Test the health route

```bash
curl "$(terraform output -raw health_url)"
```

Expected shape:

```json
{"status":"ok","service":"secure-ai-api"}
```

## 5. Test the protected generation route

```bash
curl -X POST "$(terraform output -raw generate_url)" \
  -H "Authorization: Bearer REPLACE_WITH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"prompt":"Explain least privilege in AWS in three sentences."}'
```

An invalid or missing bearer token should be rejected by API Gateway before the inference Lambda is invoked.

## 6. Validate observability

Review:

- API Gateway access log group: `/aws/apigateway/secure-ai-api-portfolio`
- Authorizer Lambda log group
- Inference Lambda log group
- API Gateway request metrics
- Lambda errors, duration, and throttles

The configured API access log format intentionally excludes authorization headers and request bodies.

## 7. Tear down lab resources

```bash
terraform destroy
```

The Secrets Manager secret has a recovery window, so AWS may retain the deleted secret temporarily according to the configured recovery policy.
