# CloudWatch Log Group for EKS Container Insights
# The cluster log group is automatically created by EKS when logging is enabled
data "aws_cloudwatch_log_group" "eks_cluster" {
  name = "/aws/eks/${local.name}-eks/cluster"
  depends_on = [module.eks]
}

# Application log group for Container Insights
resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/containerinsights/${local.name}-eks/application"
  retention_in_days = 7
  tags              = local.tags
  
  lifecycle {
    ignore_changes = [retention_in_days]
  }
}

# Performance log group for Container Insights (metrics)
resource "aws_cloudwatch_log_group" "performance" {
  name              = "/aws/containerinsights/${local.name}-eks/performance"
  retention_in_days = 7
  tags              = local.tags
  
  lifecycle {
    ignore_changes = [retention_in_days]
  }
}

# CloudWatch Alarms for High Error Rate (5xx)
resource "aws_cloudwatch_metric_alarm" "high_5xx_rate" {
  alarm_name          = "${local.name}-high-5xx-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "5xx"
  namespace           = "AWS/ApiGateway"
  period              = 300 # 5 minutes
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "This metric monitors API Gateway 5xx errors"
  alarm_actions       = []
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiId = aws_apigatewayv2_api.http.id
  }

  tags = local.tags
}

# CloudWatch Alarm for High Latency
resource "aws_cloudwatch_metric_alarm" "high_latency" {
  alarm_name          = "${local.name}-high-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Latency"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Average"
  threshold           = 1000 # 1 second in milliseconds
  alarm_description   = "This metric monitors API Gateway p95 latency"
  alarm_actions       = []
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiId = aws_apigatewayv2_api.http.id
  }

  tags = local.tags
}

# CloudWatch Alarm for DynamoDB Throttling
resource "aws_cloudwatch_metric_alarm" "dynamodb_throttle" {
  alarm_name          = "${local.name}-dynamodb-throttle"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UserErrors"
  namespace           = "AWS/DynamoDB"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "This metric monitors DynamoDB throttling events"
  alarm_actions       = []
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = aws_dynamodb_table.claims.name
  }

  tags = local.tags
}

# CloudWatch Alarm for Bedrock Errors
resource "aws_cloudwatch_metric_alarm" "bedrock_errors" {
  alarm_name          = "${local.name}-bedrock-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ModelInvocationClientError"
  namespace           = "AWS/Bedrock"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "This metric monitors Bedrock model invocation errors"
  alarm_actions       = []
  treat_missing_data  = "notBreaching"

  tags = local.tags
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiId", aws_apigatewayv2_api.http.id, { stat = "Sum", label = "Request Count" }],
          ]
          period = 300
          stat   = "Sum"
          region = var.region
          title  = "API Gateway Request Rate"
          yAxis = {
            left = {
              label = "Count"
            }
          }
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Latency", "ApiId", aws_apigatewayv2_api.http.id, { stat = "Average", label = "Average Latency" }],
            ["...", { stat = "p95", label = "P95 Latency" }],
            ["...", { stat = "p99", label = "P99 Latency" }],
          ]
          period = 300
          region = var.region
          title  = "API Gateway Latency"
          yAxis = {
            left = {
              label = "Milliseconds"
            }
          }
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApiGateway", "4xx", "ApiId", aws_apigatewayv2_api.http.id, { stat = "Sum", label = "4xx Errors", color = "#ff7f0e" }],
            [".", "5xx", ".", ".", { stat = "Sum", label = "5xx Errors", color = "#d62728" }],
          ]
          period = 300
          region = var.region
          title  = "API Gateway Error Rate"
          yAxis = {
            left = {
              label = "Count"
            }
          }
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", aws_dynamodb_table.claims.name, { stat = "Sum", label = "Read Capacity" }],
            [".", "ConsumedWriteCapacityUnits", ".", ".", { stat = "Sum", label = "Write Capacity" }],
            [".", "UserErrors", ".", ".", { stat = "Sum", label = "Throttles", yAxis = "right" }],
          ]
          period = 300
          region = var.region
          title  = "DynamoDB Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Bedrock", "Invocations", { stat = "Sum", label = "Invocations" }],
            [".", "ModelInvocationClientError", { stat = "Sum", label = "Client Errors" }],
            [".", "ModelInvocationServerError", { stat = "Sum", label = "Server Errors" }],
          ]
          period = 300
          region = var.region
          title  = "Bedrock Model Invocations"
        }
      },
      {
        type = "log"
        properties = {
          query   = "SOURCE '${aws_cloudwatch_log_group.application.name}'\n| fields @timestamp, @message\n| filter @message like /ERROR/\n| sort @timestamp desc\n| limit 20"
          region  = var.region
          title   = "Recent Application Errors"
          stacked = false
        }
      }
    ]
  })
}

# Note: EKS cluster logging is enabled via cluster_enabled_log_types in main.tf
# No additional configuration needed here

# Outputs for observability resources
output "cloudwatch_dashboard_url" {
  description = "URL to CloudWatch Dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "cloudwatch_log_group" {
  description = "CloudWatch Log Groups"
  value = {
    cluster     = data.aws_cloudwatch_log_group.eks_cluster.name
    application = aws_cloudwatch_log_group.application.name
  }
}

output "cloudwatch_alarms" {
  description = "CloudWatch Alarm names"
  value = {
    high_5xx_rate    = aws_cloudwatch_metric_alarm.high_5xx_rate.alarm_name
    high_latency     = aws_cloudwatch_metric_alarm.high_latency.alarm_name
    dynamodb_throttle = aws_cloudwatch_metric_alarm.dynamodb_throttle.alarm_name
    bedrock_errors   = aws_cloudwatch_metric_alarm.bedrock_errors.alarm_name
  }
}
