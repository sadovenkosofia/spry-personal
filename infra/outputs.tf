output "user_pool_id" {
  value = aws_cognito_user_pool.main.id
}

output "user_pool_client_id" {
  value = aws_cognito_user_pool_client.web.id
}

output "cognito_domain" {
  value = "https://${var.domain_prefix}.auth.${var.auth_region}.amazoncognito.com"
}

output "reports_bucket_name" {
  value = aws_s3_bucket.reports.bucket
}

output "queue_url" {
  value = aws_sqs_queue.requests.url
}

output "dlq_url" {
  value = aws_sqs_queue.dlq.url
}

output "builder_function_name" {
  value = aws_lambda_function.builder.function_name
}

output "mailer_function_name" {
  value = aws_lambda_function.mailer.function_name
}

output "parser_url" {
  value = aws_lambda_function_url.parser.function_url
}

output "parser_function_name" {
  value = aws_lambda_function.parser.function_name
}
