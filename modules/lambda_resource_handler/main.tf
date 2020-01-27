data "aws_caller_identity" "self" {}

resource "aws_api_gateway_resource" "create" {
  rest_api_id = var.rest_api_id
  parent_id   = var.parent_id
  path_part   = var.path_part
}

resource "aws_api_gateway_method" "create_get" {
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.create.id
  http_method = var.http_method
  authorization = var.authorization

  api_key_required = var.api_key_required
}

resource "aws_api_gateway_integration" "create_integration" {
  rest_api_id             = var.rest_api_id
  resource_id             = aws_api_gateway_resource.create.id
  http_method             = aws_api_gateway_method.create_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arn
}

resource "aws_lambda_permission" "create_get" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${var.region}:${data.aws_caller_identity.self.account_id}:${var.rest_api_id}/*/${aws_api_gateway_method.create_get.http_method}${aws_api_gateway_resource.create.path}"
}
