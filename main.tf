locals {
  package_filename = "${path.module}/package.zip"
}

data "external" "package" {
  program = ["bash", "-c", "curl -s -L -o ${local.package_filename} ${var.lambda_package_url} && echo {}"]
}

data "aws_ecs_cluster" "target" {
  cluster_name = "${var.cluster_name}"
}

resource "aws_cloudwatch_log_group" "logs" {
  name = "/aws/lambda/${var.name}"

  retention_in_days = "${var.log_retention_in_days}"
}

# Lambda
resource "aws_lambda_function" "function" {
  function_name = "${var.name}"
  handler       = "${var.handler}"
  role          = "${module.iam.arn}"
  runtime       = "${var.runtime}"
  memory_size   = "${var.memory}"
  timeout       = "${var.timeout}"
  
  filename = "${local.package_filename}"

  # Below is a very dirty hack to force base64sha256 to wait until
  # package download in data.external.package finishes.
  #
  # WARNING: explicit depends_on from this resource to data.external.package
  # does not help

  source_code_hash = "${base64sha256(file("${jsonencode(data.external.package.result) == "{}" ? local.package_filename : ""}"))}"
  tracing_config {
    mode = "${var.tracing_mode}"
  }
  environment {
    variables {
      TZ = "${var.timezone}"

      NAME_PREFIX           = "${var.name_prefix}"
      DOMAIN_NAME_PREFIX    = "${var.domain_name_prefix}"
      TARGET_CLUSTER        = "${var.cluster_name}"
      REFERENCE_SERVICE_ARN = "${var.reference_service_arn}"
      MASTER_ALB_ARN        = "${var.dynamic_alb_arn}"
      DYNAMIC_ZONE_ID       = "${var.dynamic_zone_id}"
      DYNAMIC_ZONE_NAME     = "${var.dynamic_domain_name}"
      CONFIG_BUCKET         = "${var.config_bucket_name}"
      CONFIG_BUCKET_KEY     = "${var.config_key_name}"
      CONFIG_UPDATE_KEY     = "${var.config_update_key}"
      CONFIG_NAME_PREFIX    = "${var.config_name_prefix}"
      CONFIG_ENV_TYPE       = "${var.config_env_type}"
    }
  }
  tags = "${var.tags}"
}

resource "aws_iam_role_policy_attachment" "xray_access" {
  policy_arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
  role       = "${module.iam.name}"
}

module "iam" {
  source  = "baikonur-oss/iam-nofile/aws"
  version = "1.0.1"

  type = "lambda"
  name = "${var.name}"

  policy_json = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
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
                "ecs:*"
            ],
            "Resource": [
                "arn:aws:ecs:*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject"
            ],
            "Resource": [
                "arn:aws:s3:::${var.config_bucket_name}/*"
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

# alb
resource "aws_alb" "alb" {
  count                      = "${var.count}"
  name                       = "${var.name}"
  internal                   = "${var.internal}"
  security_groups            = ["${var.api_security_group_ids}"]
  subnets                    = ["${var.api_subnet_ids}"]
  enable_deletion_protection = true
  tags                       = "${var.tags}"

  access_logs {
    enabled = true
    bucket  = "${var.api_access_logs_bucket_name}"
    prefix  = "${var.api_access_logs_prefix}"
  }
}

resource "aws_route53_record" "route53_record" {
  zone_id = "${var.api_zone_id}"
  name    = "${var.api_domain_name}"
  type    = "A"

  alias {
    name                   = "${aws_alb.alb.dns_name}"
    zone_id                = "${aws_alb.alb.zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_alb_listener" "HTTP_redirect" {
  load_balancer_arn = "${aws_alb.alb.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_alb_listener" "listener" {
  load_balancer_arn = "${aws_alb.alb.arn}"
  protocol          = "HTTPS"
  port              = 443
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-Ext-2018-06"

  certificate_arn = "${var.api_acm_certificate_arn}"

  default_action {
    target_group_arn = "${aws_lb_target_group.role.arn}"
    type             = "forward"
  }
}

resource "aws_lb_target_group" "role" {
  name        = "${var.name}"
  target_type = "lambda"
}

resource "aws_lambda_permission" "with_lb" {
  statement_id  = "AllowExecutionFromlb"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.function.arn}"
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = "${aws_lb_target_group.role.arn}"
}

resource "aws_lb_target_group_attachment" "test" {
  target_group_arn = "${aws_lb_target_group.role.arn}"
  target_id        = "${aws_lambda_function.function.arn}"
  depends_on       = ["aws_lambda_permission.with_lb"]
}
