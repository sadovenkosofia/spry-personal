resource "aws_iam_role" "mailer" {
  name               = local.mailer_role_name
  assume_role_policy = local.lambda_assume_role
}

resource "aws_iam_role_policy_attachment" "mailer_basic" {
  role       = aws_iam_role.mailer.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "mailer" {
  name = "mailer"
  role = aws_iam_role.mailer.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Read only: the mailer can never write into reports/ (no loop).
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "arn:aws:s3:::${local.bucket_name}/reports/*"
      },
      {
        Effect   = "Allow"
        Action   = ["ses:SendEmail", "ses:SendRawEmail"]
        Resource = "arn:aws:ses:${var.aws_region}:${local.account_id}:identity/*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "mailer" {
  name              = "/aws/lambda/${var.project_name}-report-mailer"
  retention_in_days = 14
}

data "archive_file" "mailer" {
  type        = "zip"
  source_file = "${path.module}/mailer/index.py"
  output_path = "${path.module}/mailer.zip"
}

resource "aws_lambda_function" "mailer" {
  function_name    = "${var.project_name}-report-mailer"
  runtime          = "python3.13"
  handler          = "index.handler"
  role             = aws_iam_role.mailer.arn
  timeout          = 30
  filename         = data.archive_file.mailer.output_path
  source_code_hash = data.archive_file.mailer.output_base64sha256

  environment {
    variables = {
      SENDER     = var.report_email
      RECIPIENTS = var.report_email
    }
  }

  depends_on = [aws_cloudwatch_log_group.mailer]
}

resource "aws_sesv2_email_identity" "report" {
  email_identity = var.report_email
}
