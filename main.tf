# Define the provider
provider "aws" {
  region = "us-east-1"
}

# Define the S3 bucket
resource "aws_s3_bucket" "data_bucket" {
  bucket = "my-data-bucket"
}

# Define the DynamoDB table
resource "aws_dynamodb_table" "processed_data" {
  name         = "processed-data"
  hash_key     = "id"
  read_capacity = 5
  write_capacity = 5

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "data"
    type = "S"
  }
}

# Define the IAM role for the Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Define the IAM policy for the Lambda function
resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda-policy"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "dynamodb:PutItem"
        ]
        Effect   = "Allow"
        Resource = [
          "${aws_s3_bucket.data_bucket.arn}/*",
          "${aws_dynamodb_table.processed_data.arn}"
        ]
      }
    ]
  })
}

# Attach the IAM policy to the IAM role
resource "aws_iam_role_policy_attachment" "lambda_attachment" {
  policy_arn = aws_iam_policy.lambda_policy.arn
  role       = aws_iam_role.lambda_role.name
}

# Define the Lambda function
resource "aws_lambda_function" "process_data" {
  function_name = "process-data"
  role          = aws_iam_role.lambda_role.arn
  handler       = "process_data.lambda_handler"
  runtime       = "python3.8"
  timeout       = 30
  memory_size   = 128

  # Package the Lambda function and dependencies into a zip file
  filename      = "process_data.zip"
  source_code_hash = filebase64sha256("process_data.zip")
}

# Define the API Gateway
resource "aws_api_gateway_rest_api" "serverless_api" {
  name        = "serverless-api"
  description = "RESTful API for the serverless application"
}

# Define the API Gateway resource
resource "aws_api_gateway_resource" "serverless_resource" {
  rest_api_id = aws_api_gateway_rest_api.serverless_api.id
  parent_id   = aws_api_gateway_rest_api.serverless_api.root_resource_id
  path_part   = "process-data"
}

# Define the API Gateway method
resource "aws_api_gateway_method" "serverless_method" {
  rest_api_id   = aws_api_gateway_rest_api.serverless_api.id
  resource_id   = aws_api_gateway_resource.serverless_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# Define the API Gateway integration for the Lambda function
resource "aws_api_gateway_integration" "serverless_integration" {
  rest_api_id = aws_api_gateway_rest_api.serverless_api.id
  resource_id = aws_api_gateway_resource.serverless_resource.id
  http_method = aws_api_gateway_method.serverless_method.http_method
  type        = "AWS_PROXY"
  uri         = aws_lambda_function.process_data.invoke_arn
}

# Define the API Gateway deployment
resource "aws_api_gateway_deployment" "serverless_deployment" {
  rest_api_id = aws_api_gateway_rest_api.serverless_api.id
  stage_name  = "prod"
}

# Output the API Gateway endpoint URL
output "api_gateway_url" {
  value = aws_api_gateway_deployment.serverless_deployment.invoke_url
}