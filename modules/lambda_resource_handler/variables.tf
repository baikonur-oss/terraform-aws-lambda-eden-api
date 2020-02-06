variable "region" {}
variable "rest_api_id" {}
variable "parent_id" {}
variable "path_part" {}
variable "lambda_invoke_arn" {}
variable "lambda_function_name" {}

variable "http_method" {
  default = "GET"
}

variable "authorization" {
  default = "NONE"
}

variable "api_key_required" {
  default = true
}
