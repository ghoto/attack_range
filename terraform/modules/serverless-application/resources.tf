

resource "aws_lambda_function" "example" {
   count = var.cloud_attack_range ? 1 : 0
   function_name = "notes_application_${var.key_name}"

   # The bucket name as created earlier with "aws s3api create-bucket"
   s3_bucket = var.cloud_s3_bucket
   s3_key    = var.cloud_s3_bucket_key

   # "main" is the filename within the zip file (main.js) and "handler"
   # is the name of the property under which the handler function was
   # exported in that file.
   handler = "wsgi_handler.handler"
   runtime = "python3.7"

   role = aws_iam_role.lambda_exec[0].arn

 }

 # IAM role which dictates what other AWS services the Lambda function
 # may access.
resource "aws_iam_role" "lambda_exec" {
   count = var.cloud_attack_range ? 1 : 0
   name = "iam_roles_notes_app_${var.key_name}"

   assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "lambda.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF

}


# See also the following AWS managed policy: AWSLambdaBasicExecutionRole
resource "aws_iam_policy" "lambda_logging" {
  count       = var.cloud_attack_range ? 1 : 0
  name        = "lambda_logging_${var.key_name}"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "lambda_dynamodb_access" {
  count       = var.cloud_attack_range ? 1 : 0
  name        = "lambda_dynamodb_access_${var.key_name}"
  path        = "/"
  description = "IAM policy for RDS access"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
      			"Effect": "Allow",
      			"Action": [
      			     "dynamodb:BatchGetItem",
      				   "dynamodb:GetItem",
      			     "dynamodb:Query",
      				   "dynamodb:Scan",
      				   "dynamodb:BatchWriteItem",
      				   "dynamodb:PutItem",
      				   "dynamodb:UpdateItem"
      			],
      			"Resource": ["${aws_dynamodb_table.notes_table[0].arn}*",
                "${aws_dynamodb_table.users_table[0].arn}*"]
  		  }
    ]
}
EOF
}


resource "aws_iam_role_policy_attachment" "lambda_logs" {
  count      = var.cloud_attack_range ? 1 : 0
  role       = "${aws_iam_role.lambda_exec[0].name}"
  policy_arn = "${aws_iam_policy.lambda_logging[0].arn}"
}

resource "aws_iam_role_policy_attachment" "lambda_rds" {
  count      = var.cloud_attack_range ? 1 : 0
  role       = "${aws_iam_role.lambda_exec[0].name}"
  policy_arn = "${aws_iam_policy.lambda_dynamodb_access[0].arn}"
}


## REST API Gateway

resource "aws_cloudwatch_log_group" "rest_api" {
  count             = var.cloud_attack_range ? 1 : 0
  name              = "API-Gateway-Execution-Logs_${aws_api_gateway_rest_api.example[0].id}/prod"
  retention_in_days = 7
}

resource "aws_api_gateway_method_settings" "s" {
  count       = var.cloud_attack_range ? 1 : 0
  rest_api_id = "${aws_api_gateway_rest_api.example[0].id}"
  stage_name  = "${aws_api_gateway_stage.prod[0].stage_name}"
  method_path = "*/*"

  settings {
    metrics_enabled = true
    logging_level   = "INFO"
  }
}


resource "aws_api_gateway_rest_api" "example" {
  count       = var.cloud_attack_range ? 1 : 0
  name        = "api_gateway_${var.key_name}"
  description = "Attack Range Rest API Notes Application"
}


resource "aws_api_gateway_stage" "prod" {
  count          = var.cloud_attack_range ? 1 : 0
  depends_on    = ["aws_cloudwatch_log_group.rest_api[0]"]
  stage_name    = "prod"
  rest_api_id   = aws_api_gateway_rest_api.example[0].id
  deployment_id = aws_api_gateway_deployment.example[0].id
}

resource "aws_api_gateway_resource" "proxy" {
  count       = var.cloud_attack_range ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.example[0].id
  parent_id   = aws_api_gateway_rest_api.example[0].root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
  count         = var.cloud_attack_range ? 1 : 0
  rest_api_id   = aws_api_gateway_rest_api.example[0].id
  resource_id   = aws_api_gateway_resource.proxy[0].id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda" {
   count       = var.cloud_attack_range ? 1 : 0
   rest_api_id = aws_api_gateway_rest_api.example[0].id
   resource_id = aws_api_gateway_method.proxy[0].resource_id
   http_method = aws_api_gateway_method.proxy[0].http_method

   integration_http_method = "POST"
   type                    = "AWS_PROXY"
   uri                     = aws_lambda_function.example[0].invoke_arn
 }

 resource "aws_api_gateway_method" "proxy_root" {
   count         = var.cloud_attack_range ? 1 : 0
   rest_api_id   = aws_api_gateway_rest_api.example[0].id
   resource_id   = aws_api_gateway_rest_api.example[0].root_resource_id
   http_method   = "ANY"
   authorization = "NONE"
 }

 resource "aws_api_gateway_integration" "lambda_root" {
   count       = var.cloud_attack_range ? 1 : 0
   rest_api_id = aws_api_gateway_rest_api.example[0].id
   resource_id = aws_api_gateway_method.proxy_root[0].resource_id
   http_method = aws_api_gateway_method.proxy_root[0].http_method

   integration_http_method = "POST"
   type                    = "AWS_PROXY"
   uri                     = aws_lambda_function.example[0].invoke_arn
 }

 resource "aws_api_gateway_deployment" "example" {
   count       = var.cloud_attack_range ? 1 : 0
   depends_on = [
     aws_api_gateway_integration.lambda[0],
     aws_api_gateway_integration.lambda_root[0],
   ]

   rest_api_id = aws_api_gateway_rest_api.example[0].id
 }

 resource "aws_lambda_permission" "apigw" {
  count       = var.cloud_attack_range ? 1 : 0
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.example[0].function_name
  principal     = "apigateway.amazonaws.com"

  # The "/*/*" portion grants access from any method on any resource
  # within the API Gateway REST API.
  source_arn = "${aws_api_gateway_rest_api.example[0].execution_arn}/*/*"
}



## AWS dynamodb table

resource "aws_dynamodb_table" "users_table" {
  count = var.cloud_attack_range ? 1 : 0
  name           = "Users"
  billing_mode   = "PROVISIONED"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "UserName"

  attribute {
    name = "UserName"
    type = "S"
  }

  ttl {
    attribute_name = "TimeToExist"
    enabled        = false
  }

  tags = {
    Name        = "dynamodb-table-users-${var.key_name}"
  }
}


resource "aws_dynamodb_table" "notes_table" {
  count = var.cloud_attack_range ? 1 : 0
  name           = "Notes"
  billing_mode   = "PROVISIONED"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "UserName"
  range_key      = "TimeStamp"

  attribute {
    name = "UserName"
    type = "S"
  }

  attribute {
    name = "TimeStamp"
    type = "S"
  }

  ttl {
    attribute_name = "TimeToExist"
    enabled        = false
  }

  tags = {
    Name        = "dynamodb-table-notes-${var.key_name}"
  }
}