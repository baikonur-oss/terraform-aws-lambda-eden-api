variable "region" {
  description = "Region to create API Gateway in. \"default\" will select provider's current region"
  default     = "default"
}

# Lambda
variable "timezone" {
  description = "tz database timezone name (e.g. Asia/Tokyo)"
  default     = "UTC"
}

variable "memory" {
  description = "Lambda Function memory in megabytes"
  default     = 256
}

variable "timeout" {
  description = "Lambda Function timeout in seconds"
  default     = 60
}

variable "lambda_package_url" {
  description = "Lambda package URL (see Usage in README)"
}

variable "handler" {
  description = "Lambda Function handler (entrypoint)"
  default     = "main.lambda_handler"
}

variable "runtime" {
  description = "Lambda Function runtime"
  default     = "python3.7"
}

variable "name" {
  description = "Resource name"
  default     = "eden"
}

variable "tracing_mode" {
  description = "X-Ray tracing mode (see: https://docs.aws.amazon.com/lambda/latest/dg/API_TracingConfig.html )"
  default     = "PassThrough"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "eden_table" {
  description = "eden DynamoDB table name for profiles and envs"
  default     = "eden"
}

variable "api_acm_certificate_arn" {
   description = "ACM certificate ARN for eden API Gateway"
}

## s3 bucket
variable "endpoints_bucket_name" {
  description = "S3 bucket name containing endpoints JSON file"
}

### route53
variable "api_zone_id" {
  description = "Route 53 Zone ID for eden API ALB"
}

variable "api_domain_name" {
  description = "eden API domain name"
}

variable "dynamic_zone_id" {
  description = "Route 53 Zone ID of zone to use to create environments"
}

variable "log_retention_in_days" {
  description = "eden API Lambda Function log retention in days"
  default     = 30
}
