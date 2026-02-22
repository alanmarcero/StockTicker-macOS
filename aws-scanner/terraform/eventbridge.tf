resource "aws_scheduler_schedule" "weekly" {
  name       = "ema-scanner-weekly"
  group_name = "default"

  schedule_expression          = "cron(0 14 ? * FRI *)"
  schedule_expression_timezone = "America/New_York"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.orchestrator.arn
    role_arn = aws_iam_role.scheduler.arn
  }
}
