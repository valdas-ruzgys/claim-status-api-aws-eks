# Observability

## CloudWatch Logs Insights queries

- Recent API errors (HTTP 4xx/5xx):
```
fields @timestamp, @message
| filter @message like /"statusCode":(4|5)\d{2}/
| sort @timestamp desc
| limit 50
```
- Latency p95 by route:
```
fields @timestamp, path, latency
| stats pct(latency, 95) by path
```
- Bedrock invocation failures:
```
fields @timestamp, @message
| filter @message like /Bedrock/ and @message like /error|Exception|Timeout/
| sort @timestamp desc
```

## Metrics
- Publish `http_requests_total`, `http_request_duration_seconds` via Prometheus (kube-state-metrics + scraping on app) or AWS Distro for OpenTelemetry exporter.
- Create CloudWatch alarms: high 5xx rate (>2% for 5 minutes), elevated latency (p95 > 1s), Bedrock errors (>1/min).

## Dashboards
- Include widgets for: request rate, p95 latency, error rate, DynamoDB throttle count, EKS node CPU/memory, Bedrock invocation count.

## Tracing
- Enable ADOT Collector on EKS; export traces to X-Ray.

## Samples
- Place screenshots in `observability/screenshots/` (placeholder names: `latency-dashboard.png`, `logs-insights.png`).
