# ECS Dynamic Environment Manager (eden) API 

Terraform module for Dynamic Environment Manager (eden) API

Clone ECS environments easily. 
Provide eden with a sample ECS service and eden will clone it.

eden is provided in CLI and Terraform module (Lambda with HTTP API) flavors. 
You can use HTTP API from CI of your choice on Pull Request open/close, 
new commit pushes to fully automate environment creation. 
For CLI flavor, see aws-eden-cli at [GitHub](https://github.com/baikonur-oss/aws-eden-cli).

![terraform v0.11.x](https://img.shields.io/badge/terraform-v0.11.x-brightgreen.svg)

## Developing with eden

![simple-figure](figures/aws-eden-simple-en.png)

## Usage (API interface)
```HCL
module "eden" {
  source  = "baikonur-oss/lambda-eden-api/aws"
  version = "0.1.0"

  lambda_package_url = "https://github.com/baikonur-oss/terraform-aws-lambda-eden-api/releases/download/v0.1.0/lambda_package.zip"
  name                  = "dev-api-eden"

  # eden API ALB variables
  api_subnet_ids              = ["subnet-0123456", "subnet-0123457"]
  api_security_group_ids      = ["sg-xxxxxxx"]
  api_acm_certificate_arn     = "${data.aws_acm_certificate.wildcard.arn}"
  api_domain_name             = "${var.env}-eden.${data.aws_route53_zone.main.name}"
  api_zone_id                 = "${data.aws_route53_zone.main.zone_id}"
  api_access_logs_bucket_name = "${data.aws_s3_bucket.logs.bucket}"
  api_access_logs_prefix      = "alb/accesslogs-${local.name}-eden-api"

  # config file location
  config_bucket_name = "somebucket"
  config_key_name    = "config.json"

  # config values
  config_env_type    = "dev"
  config_update_key  = "api_endpoint"
  config_name_prefix = "dev-dynamic"

  # dynamic resource template, parameters, name prefixes
  name_prefix           = "dev-dynamic"
  domain_name_prefix    = "api"
  cluster_name          = "dev"
  reference_service_arn = "${data.aws_ecs_service.ref.arn}"
  
  # common ALB
  dynamic_alb_arn       = "${data.aws_lb.dynamic.arn}"
  dynamic_domain_name   = "${data.aws_route53_zone.dynamic.name}"
  dynamic_zone_id       = "${data.aws_route53_zone.dynamic.zone_id}"
}
```

### Example
#### Create API
`curl https://eden.example.com/api/v1/create?branch=test-create&cirn=xxxxxxxxxxxx.dkr.ecr.ap-northeast-1.amazonaws.com/servicename-api-dev:latest`

```
2019-04-08T20:32:05.151Z INFO     [main.py:check_cirn:382] Checking if image xxxxxxxxxxxx.dkr.ecr.ap-northeast-1.amazonaws.com/servicename-api-dev:latest exists 
2019-04-08T20:32:05.270Z INFO     [main.py:check_cirn:401] Image exists 
2019-04-08T20:32:05.446Z INFO     [main.py:create_env:509] Retrieved reference service arn:aws:ecs:ap-northeast-1:xxxxxxxxxxxx:service/dev/dev01-api 
2019-04-08T20:32:05.484Z INFO     [main.py:create_task_definition:58] Retrieved reference task definition from arn:aws:ecs:ap-northeast-1:xxxxxxxxxxxx:task-definition/dev01-api:15 
2019-04-08T20:32:05.557Z INFO     [main.py:create_task_definition:96] Registered new task definition: arn:aws:ecs:ap-northeast-1:xxxxxxxxxxxx:task-definition/dev-dynamic-test-create:1 
2019-04-08T20:32:05.584Z INFO     [main.py:create_target_group:112] Retrieved reference target group: arn:aws:elasticloadbalancing:ap-northeast-1:xxxxxxxxxxxx:targetgroup/dev01-api/9c68a5f91f34d9a4 
2019-04-08T20:32:05.611Z INFO     [main.py:create_target_group:125] Existing target group dev-dynamic-test-create not found, will create new 
2019-04-08T20:32:06.247Z INFO     [main.py:create_target_group:144] Created target group 
2019-04-08T20:32:06.310Z INFO     [main.py:create_alb_host_listener_rule:355] ELBv2 listener rule for target group arn:aws:elasticloadbalancing:ap-northeast-1:xxxxxxxxxxxx:targetgroup/dev-dynamic-test-create/b6918e6e5f10389d and host api-test-create.dev.example.com does not exist, will create new listener rule 
2019-04-08T20:32:06.361Z INFO     [main.py:create_env:554] ECS Service dev-dynamic-test-create does not exist, will create new service 
2019-04-08T20:32:07.672Z INFO     [main.py:check_record:414] Checking if record api-test-create.dev.example.com. exists in zone Zxxxxxxxxxxxx 
2019-04-08T20:32:08.133Z INFO     [main.py:create_cname_record:477] Successfully created CNAME: api-test-create.dev.example.com -> dev-alb-api-dynamic-xxxxxxxxx.ap-northeast-1.elb.amazonaws.com 
2019-04-08T20:32:08.134Z INFO     [main.py:create_env:573] Successfully finished creating environment dev-dynamic-test-create 
```
#### Create API on existing env
`curl https://eden.example.com/api/v1/create?branch=add-nothing&cirn=xxxxxxxxxxxx.dkr.ecr.ap-northeast-1.amazonaws.com/servicename-api-dev:latest`

```
2019-04-08T20:30:13.491Z INFO     [main.py:check_cirn:382] Checking if image xxxxxxxxxxxx.dkr.ecr.ap-northeast-1.amazonaws.com/servicename-api-dev:latest exists 
2019-04-08T20:30:13.553Z INFO     [main.py:check_cirn:401] Image exists 
2019-04-08T20:30:13.692Z INFO     [main.py:create_env:509] Retrieved reference service arn:aws:ecs:ap-northeast-1:xxxxxxxxxxxx:service/dev/dev01-api 
2019-04-08T20:30:13.721Z INFO     [main.py:create_task_definition:58] Retrieved reference task definition from arn:aws:ecs:ap-northeast-1:xxxxxxxxxxxx:task-definition/dev01-api:15 
2019-04-08T20:30:13.788Z INFO     [main.py:create_task_definition:96] Registered new task definition: arn:aws:ecs:ap-northeast-1:xxxxxxxxxxxx:task-definition/dev-dynamic-add-nothing:5 
2019-04-08T20:30:13.807Z INFO     [main.py:create_target_group:112] Retrieved reference target group: arn:aws:elasticloadbalancing:ap-northeast-1:xxxxxxxxxxxx:targetgroup/dev01-api/9c68a5f91f34d9a4 
2019-04-08T20:30:13.827Z INFO     [main.py:create_target_group:147] Target group dev-dynamic-add-nothing already exists, skipping creation 
2019-04-08T20:30:13.877Z INFO     [main.py:create_alb_host_listener_rule:351] ELBv2 listener rule for target group arn:aws:elasticloadbalancing:ap-northeast-1:xxxxxxxxxxxx:targetgroup/dev-dynamic-add-nothing/xxxxxxxx already exists, skipping creation 
2019-04-08T20:30:13.926Z INFO     [main.py:create_env:538] ECS Service dev-dynamic-add-nothing already exists, skipping creation 
2019-04-08T20:30:13.926Z INFO     [main.py:create_env:539] Will deploy task definition arn:aws:ecs:ap-northeast-1:xxxxxxxxxxxx:task-definition/dev-dynamic-add-nothing:5 to service dev-dynamic-add-nothing 
2019-04-08T20:30:14.429Z INFO     [main.py:create_env:549] Successfully deployed task definition arn:aws:ecs:ap-northeast-1:xxxxxxxxxxxx:task-definition/dev-dynamic-add-nothing:5 to service dev-dynamic-add-nothing in cluster dev 
2019-04-08T20:30:15.248Z INFO     [main.py:check_record:414] Checking if record api-add-nothing.dev.example.com. exists in zone Zxxxxxxxxxxxx 
2019-04-08T20:30:15.552Z INFO     [main.py:check_record:425] Found existing record api-add-nothing.dev.example.com. in zone Zxxxxxxxxxxxx 
2019-04-08T20:30:15.552Z INFO     [main.py:create_cname_record:450] CNAME record already exists, doing nothing: api-add-nothing.dev.example.com -> dev-alb-api-dynamic-xxxxxxxxx.ap-northeast-1.elb.amazonaws.com 
2019-04-08T20:30:15.552Z INFO     [main.py:create_env:573] Successfully finished creating environment dev-dynamic-add-nothing 
```

#### Delete API (existing env)
`curl https://eden.example.com/api/v1/delete?branch=add-nothing`

```
2019-04-10T23:11:38.515Z INFO     [main.py:check_record:495] Checking if record api-add-nothing.dev.example.com. exists in zone Zxxxxxxxxxxxx 
2019-04-10T23:11:38.752Z INFO     [main.py:check_record:506] Found existing record api-add-nothing.dev.example.com. in zone Zxxxxxxxxxxxx 
2019-04-10T23:11:38.996Z INFO     [main.py:delete_cname_record:596] Successfully removed CNAME record api-add-nothing.dev.example.com 
2019-04-10T23:11:39.245Z INFO     [main.py:delete_env:665] ECS Service dev-dynamic-add-nothing exists, will delete 
2019-04-10T23:11:39.401Z INFO     [main.py:delete_env:670] Successfully deleted service dev-dynamic-add-nothing from cluster dev 
2019-04-10T23:11:39.573Z INFO     [main.py:delete_alb_host_listener_rule:397] ELBv2 listener rule for target group arn:aws:elasticloadbalancing:ap-northeast-1:xxxxxxxxxxxx:targetgroup/dev-dynamic-add-nothing/xxxxxxxx and host api-add-nothing.dev.example.com found, will delete 
2019-04-10T23:11:40.483Z INFO     [main.py:delete_env:697] Deleted all task definitions for family: dev-dynamic-add-nothing, 5 tasks deleted total 
2019-04-10T23:11:40.483Z INFO     [main.py:delete_env:700] Successfully finished deleting environment dev-dynamic-add-nothing 
```

#### Delete API (non-existent env)
`curl https://eden.example.com/api/v1/delete?branch=add-nothing`

```
2019-04-10T23:14:46.216Z INFO     [main.py:check_record:495] Checking if record api-add-nothing.dev.example.com. exists in zone Zxxxxxxxxxxxx 
2019-04-10T23:14:46.514Z INFO     [main.py:delete_cname_record:600] CNAME record for api-add-nothing.dev.example.com does not exist, skipping deletion 
2019-04-10T23:14:46.872Z INFO     [main.py:delete_env:662] ECS Service dev-dynamic-add-nothing not found, skipping deletion 
2019-04-10T23:14:46.923Z INFO     [main.py:delete_env:691] Target group dev-dynamic-add-nothing not found, skipping deletion of listener rule and target group 
2019-04-10T23:14:46.991Z INFO     [main.py:delete_env:697] Deleted all task definitions for family: dev-dynamic-add-nothing, 0 tasks deleted total 
2019-04-10T23:14:46.991Z INFO     [main.py:delete_env:700] Successfully finished deleting environment dev-dynamic-add-nothing 
```

### Version pinning
#### Terraform Module Registry
Use `version` parameter to pin to a specific version, or to specify a version constraint when pulling from [Terraform Module Registry](https://registry.terraform.io) (`source = baikonur-oss/%module_name%/aws`).
For more information, refer to [Module Versions](https://www.terraform.io/docs/configuration/modules.html#module-versions) section of Terraform Modules documentation.

#### GitHub URI
Make sure to use `?ref=` version pinning in module source URI when pulling from GitHub.
Pulling from GitHub is especially useful for development, as you can pin to a specific branch, tag or commit hash.
Example: `source = github.com/baikonur-oss/%repo_name%?ref=v1.0.0`

For more information on module version pinning, see [Selecting a Revision](https://www.terraform.io/docs/modules/sources.html#selecting-a-revision) section of Terraform Modules documentation.

<!-- Documentation below is generated by pre-commit, do not overwrite manually -->
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| api\_access\_logs\_bucket\_name | S3 bucket name for saving eden API access logs | string | n/a | yes |
| api\_access\_logs\_prefix | Path prefix for eden API access logs | string | n/a | yes |
| api\_acm\_certificate\_arn | ACM certificate ARN for eden API ALB | string | n/a | yes |
| api\_domain\_name | eden API domain name | string | n/a | yes |
| api\_security\_group\_ids | List of security group IDs for eden API ALB to use | list | n/a | yes |
| api\_subnet\_ids | List of subnet IDs for eden API ALB to use | list | n/a | yes |
| api\_zone\_id | Route 53 Zone ID for eden API ALB | string | n/a | yes |
| batch\_size | Maximum number of records passed for a single Lambda invocation | string | n/a | yes |
| cluster\_name | ECS Cluster name (must include reference_service_arn) | string | n/a | yes |
| config\_bucket\_name | S3 bucket name containing Config JSON file | string | n/a | yes |
| config\_env\_type | Static string to put for env key in Config JSON file (e.g. dev/stg/prd) | string | n/a | yes |
| config\_key\_name | Config JSON file key | string | n/a | yes |
| config\_name\_prefix | Prefix for environment name in Config JSON file | string | n/a | yes |
| config\_update\_key | Key to put DNS hostnames created by eden to in Config JSON file | string | n/a | yes |
| count |  | string | `"1"` | no |
| domain\_name\_prefix | Prefix for domain names created by eden | string | n/a | yes |
| dynamic\_alb\_arn | ARN of dynamic environment common ALB | string | n/a | yes |
| dynamic\_domain\_name | Route 53 Zone name to use to create dynamic environments | string | n/a | yes |
| dynamic\_zone\_id | Route 53 Zone ID of zone to use to create dynamic environments | string | n/a | yes |
| handler | Lambda Function handler (entrypoint) | string | `"main.lambda_handler"` | no |
| internal | # alb | string | `"false"` | no |
| lambda\_package\_url | Lambda package URL (see Usage in README) | string | n/a | yes |
| log\_retention\_in\_days | eden API Lambda Function log retention in days | string | `"30"` | no |
| memory | Lambda Function memory in megabytes | string | `"256"` | no |
| name | Resource name | string | `"env_manager"` | no |
| name\_prefix | Prefix to use in names for resources created by eden | string | n/a | yes |
| reference\_service\_arn | Reference ECS Service ARN | string | n/a | yes |
| runtime | Lambda Function runtime | string | `"python3.7"` | no |
| tags | Resource tags | map | `<map>` | no |
| timeout | Lambda Function timeout in seconds | string | `"60"` | no |
| timezone | tz database timezone name (e.g. Asia/Tokyo) | string | `"UTC"` | no |
| tracing\_mode | X-Ray tracing mode (see: https://docs.aws.amazon.com/lambda/latest/dg/API_TracingConfig.html ) | string | `"PassThrough"` | no |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Contributing

Make sure to have following tools installed:
- [Terraform](https://www.terraform.io/)
- [terraform-docs](https://github.com/segmentio/terraform-docs)
- [pre-commit](https://pre-commit.com/)

### macOS
```bash
brew install pre-commit terraform terraform-docs

# set up pre-commit hooks by running below command in repository root
pre-commit install
```
