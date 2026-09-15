variable "aws_region" {
  description = "AWS Region for the API stack and Bedrock model."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used in resource names."
  type        = string
  default     = "secure-ai-api"
}

variable "environment" {
  description = "Environment label."
  type        = string
  default     = "portfolio"
}

variable "bedrock_model_id" {
  description = "Amazon Bedrock foundation model ID invoked by the API."
  type        = string
  default     = "amazon.nova-lite-v1:0"
}

variable "allowed_origins" {
  description = "CORS origins allowed to call the API from a browser."
  type        = list(string)
  default     = ["https://dumm.cloud"]
}

variable "max_prompt_chars" {
  description = "Maximum accepted prompt length enforced by Lambda."
  type        = number
  default     = 4000
}

variable "log_retention_days" {
  description = "CloudWatch log retention period."
  type        = number
  default     = 30
}

variable "throttling_burst_limit" {
  description = "API Gateway burst request limit."
  type        = number
  default     = 20
}

variable "throttling_rate_limit" {
  description = "API Gateway sustained requests per second."
  type        = number
  default     = 10
}

variable "tags" {
  description = "Additional tags for supported resources."
  type        = map(string)
  default     = {}
}
