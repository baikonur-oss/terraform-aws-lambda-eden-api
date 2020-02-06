locals {
  package_filename = "${path.module}/package.zip"
  region           = var.region == "default" ? data.aws_region.current.name : var.region
}

data "aws_region" "current" {}

data "aws_dynamodb_table" "eden" {
  name = var.eden_table
}

data "external" "package" {
  program = ["bash", "-c", "curl -s -L -o ${local.package_filename} ${var.lambda_package_url} && echo {}"]
}

resource "aws_cloudwatch_log_group" "logs" {
  name = "/aws/lambda/${var.name}"

  retention_in_days = var.log_retention_in_days
}

# Lambda
resource "aws_lambda_function" "function" {
  function_name = var.name
  handler       = var.handler
  role          = module.iam.arn
  runtime       = var.runtime
  memory_size   = var.memory
  timeout       = var.timeout

  # Below is a very dirty hack to force base64sha256 to wait until
  # package download in data.external.package finishes.
  #
  # WARNING: explicit depends_on from this resource to data.external.package
  # does not help

  filename = local.package_filename

  source_code_hash = filebase64sha256(
    jsonencode(data.external.package.result) == "{}" ? local.package_filename : "",
  )

  tracing_config {
    mode = var.tracing_mode
  }

  environment {
    variables = {
      TZ         = var.timezone
      EDEN_TABLE = var.eden_table
    }
  }

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "xray_access" {
  policy_arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
  role       = module.iam.name
}

module "iam" {
  source  = "baikonur-oss/iam-nofile/aws"
  version = "v2.0.0"

  type = "lambda"
  name = var.name

  policy_json = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:*:*:*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:*"
            ],
            "Resource": [
                "arn:aws:ec2:*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:*"
            ],
            "Resource": [
                "${data.aws_dynamodb_table.eden.arn}",
                "${data.aws_dynamodb_table.eden.arn}/*",
                "${data.aws_dynamodb_table.eden.arn}/index/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject"
            ],
            "Resource": [
                "arn:aws:s3:::${var.endpoints_bucket_name}/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "route53:ChangeResourceRecordSets"
            ],
            "Resource": "arn:aws:route53:::hostedzone/${var.dynamic_zone_id}"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ecr:*"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:*"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ecs:*"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "iam:PassRole"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "route53:GetHostedZone",
                "route53:ListResourceRecordSets"
            ],
            "Resource": "arn:aws:route53:::hostedzone/${var.dynamic_zone_id}"
        }
   ]
}
EOF

}

## API Gateway REST API

resource "aws_api_gateway_rest_api" "api" {
  name        = var.name
  description = "eden API managed by Terraform"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_domain_name" "eden" {
  domain_name              = replace(var.api_domain_name, "/[.]$/", "")
  regional_certificate_arn = var.api_acm_certificate_arn
  security_policy          = "TLS_1_2"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_base_path_mapping" "mapping" {
  api_id      = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_deployment.main.stage_name
  domain_name = aws_api_gateway_domain_name.eden.domain_name
}

resource "aws_route53_record" "eden" {
  name    = aws_api_gateway_domain_name.eden.domain_name
  type    = "A"
  zone_id = var.api_zone_id

  alias {
    evaluate_target_health = true
    name                   = aws_api_gateway_domain_name.eden.regional_domain_name
    zone_id                = aws_api_gateway_domain_name.eden.regional_zone_id
  }
}

resource "aws_api_gateway_resource" "api" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "api"
}

resource "aws_api_gateway_resource" "v1" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = "v1"
}

### GET create API
module "create" {
  source = "./modules/lambda_resource_handler"
  region = local.region

  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.v1.id
  path_part   = "create"

  lambda_function_name = aws_lambda_function.function.function_name
  lambda_invoke_arn    = aws_lambda_function.function.invoke_arn
}

### GET delete API
module "delete" {
  source = "./modules/lambda_resource_handler"
  region = local.region

  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.v1.id
  path_part   = "delete"

  lambda_function_name = aws_lambda_function.function.function_name
  lambda_invoke_arn    = aws_lambda_function.function.invoke_arn
}

## Stages
resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = "main"
}

### Usage plans and keys
resource "aws_api_gateway_usage_plan" "std" {
  name        = "eden-std-plan"
  description = "eden standard usage plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.api.id
    stage  = aws_api_gateway_deployment.main.stage_name
  }
}

resource "aws_api_gateway_api_key" "std" {
  name = "eden-std-key"
}

resource "aws_api_gateway_usage_plan_key" "main" {
  key_id        = aws_api_gateway_api_key.std.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.std.id
}
