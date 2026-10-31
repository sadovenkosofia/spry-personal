resource "aws_iam_role" "builder" {
  name               = local.builder_role_name
  assume_role_policy = local.lambda_assume_role
}

resource "aws_iam_role_policy_attachment" "builder_vpc" {
  role       = aws_iam_role.builder.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "builder" {
  name = "builder"
  role = aws_iam_role.builder.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${local.bucket_name}/reports/*"
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = aws_sqs_queue.requests.arn
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "builder" {
  name              = "/aws/lambda/${var.project_name}-report-builder"
  retention_in_days = 14
}

resource "aws_lambda_function" "builder" {
  function_name = "${var.project_name}-report-builder"
  package_type  = "Image"
  image_uri     = var.builder_image_uri
  role          = aws_iam_role.builder.arn
  timeout       = 60
  memory_size   = 512

  image_config {
    command = ["app.reports.lambda_handler.handler"]
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.security_group_id]
  }

  environment {
    variables = {
      DATABASE_URL   = var.database_url
      REPORTS_BUCKET = local.bucket_name
      FAIL_WEEK      = var.fail_week
    }
  }

  lifecycle {
    # DATABASE_URL is a secret that Terraform cannot compare reliably.
    # Leave the Lambda environment untouched after adoption.
    ignore_changes = [environment]
  }

  depends_on = [aws_cloudwatch_log_group.builder]
}

resource "aws_lambda_event_source_mapping" "builder" {
  event_source_arn = aws_sqs_queue.requests.arn
  function_name    = aws_lambda_function.builder.arn
  batch_size       = 1
}

