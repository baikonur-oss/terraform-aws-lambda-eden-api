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
  default     = "env_manager"
}

variable "tracing_mode" {
  description = "X-Ray tracing mode (see: https://docs.aws.amazon.com/lambda/latest/dg/API_TracingConfig.html )"
  default     = "PassThrough"
}

variable "tags" {
  description = "Resource tags"
  type        = "map"
  default     = {}
}

variable "name_prefix" {
  description = "Prefix to use in names for resources created by eden"
}

## alb
variable "internal" {
  description = "Should eden API ALB be internal?"
  default     = false
}

variable "count" {
  default = 1
}

variable "api_subnet_ids" {
  description = "List of subnet IDs for eden API ALB to use"
  type        = "list"
}

variable "api_security_group_ids" {
  description = "List of security group IDs for eden API ALB to use"
  type        = "list"
}

variable "api_access_logs_bucket_name" {
  description = "S3 bucket name for saving eden API access logs"
}

variable "api_access_logs_prefix" {
  description = "Path prefix for eden API access logs"
}

variable "api_acm_certificate_arn" {
  description = "ACM certificate ARN for eden API ALB"
}

## s3 bucket

variable "config_bucket_name" {
  description = "S3 bucket name containing Config JSON file"
}

variable "config_key_name" {
  description = "Config JSON file key"
}

variable "config_update_key" {
  description = "Key to put DNS hostnames created by eden to in Config JSON file"
}

variable "config_env_type" {
  description = "Static string to put for env key in Config JSON file (e.g. dev/stg/prd)"
}

variable "config_name_prefix" {
  description = "Prefix for environment name in Config JSON file"
}

variable "reference_service_arn" {
  description = "Reference ECS Service ARN"
}

### route53

variable "api_zone_id" {
  description = "Route 53 Zone ID for eden API ALB"
}

variable "api_domain_name" {
  description = "eden API domain name"
}

variable "dynamic_zone_id" {
  description = "Route 53 Zone ID of zone to use to create dynamic environments"
}

variable "dynamic_domain_name" {
  description = "Route 53 Zone name to use to create dynamic environments"
}

variable "dynamic_alb_arn" {
  description = "ARN of dynamic environment common ALB"
}

variable "domain_name_prefix" {
  description = "Prefix for domain names created by eden"
}

variable "cluster_name" {
  description = "ECS Cluster name (must include reference_service_arn)"
}

variable "log_retention_in_days" {
  description = "eden API Lambda Function log retention in days"
  default     = 30
}
