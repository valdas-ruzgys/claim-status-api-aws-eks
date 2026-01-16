# Observability

This project uses **AWS CloudWatch Container Insights** for comprehensive observability, providing automated collection of logs, metrics, and performance data from EKS.

## Deployed Resources

Terraform automatically provisions:

- **CloudWatch Log Groups**:
  - `/aws/eks/claim-status-eks/cluster` - EKS control plane logs
  - `/aws/containerinsights/claim-status-eks/application` - Application logs from pods
  - `/aws/containerinsights/claim-status-eks/performance` - Container and node metrics

- **EKS Add-on**: `amazon-cloudwatch-observability`
  - Automatically deployed by Terraform
  - Manages Fluent Bit DaemonSet for log collection
  - Collects container, pod, node, and cluster metrics
  - No manual IRSA configuration required

- **CloudWatch Dashboard** (`claim-status-dashboard`):
  - API Gateway request count, 4xx/5xx errors, latency
  - DynamoDB consumed read/write capacity, throttled requests
  - Bedrock invocation count and error metrics

- **CloudWatch Alarms**:
  - `claim-status-high-5xx-rate` - Triggers when 5xx rate > 2% over 5 minutes
  - `claim-status-high-latency` - Triggers when p95 latency > 1000ms over 5 minutes
  - `claim-status-dynamodb-throttle` - Triggers on DynamoDB throttle events
  - `claim-status-bedrock-errors` - Triggers on Bedrock invocation errors

## Container Insights Benefits

✅ **Automatic collection** of:

- Application logs (stdout/stderr from all containers)
- Container metrics (CPU, memory, network, disk)
- Pod-level metrics
- Node-level metrics
- Cluster-level aggregations

✅ **Pre-built dashboards** for:

- Cluster overview
- Node performance
- Pod performance
- Namespace insights

✅ **No manual configuration** - managed by EKS add-on

## Accessing Logs

### Via AWS Console

**Container Insights Dashboard:**

```bash
# Get the Container Insights URL (or navigate manually)
echo "https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#container-insights:infrastructure/map/claim-status-eks"
```

Navigate to: CloudWatch → Container Insights → Select cluster

**CloudWatch Logs:**

**CloudWatch Logs:**

```bash
# Get CloudWatch dashboard URL
terraform output cloudwatch_dashboard_url

# Or navigate to:
# AWS Console → CloudWatch → Dashboards → claim-status-dashboard
```

### Via AWS CLI

```bash
# Tail application logs in real-time
aws logs tail /aws/containerinsights/claim-status-eks/application --follow

# Get recent logs
aws logs tail /aws/containerinsights/claim-status-eks/application --since 1h

# Performance metrics logs
aws logs tail /aws/containerinsights/claim-status-eks/performance --since 1h

# Cluster control plane logs
aws logs tail /aws/eks/claim-status-eks/cluster --follow
```

### Via kubectl

```bash
# Application pod logs
kubectl logs -l app=claim-status-api --tail=100 -f

# Check Container Insights pods (managed by add-on)
kubectl get pods -n amazon-cloudwatch
```

## CloudWatch Logs Insights

Log Group: `/aws/containerinsights/claim-status-eks/application`

## Metrics & Dashboards

The CloudWatch dashboard includes:

- **API Gateway Metrics**:
  - Request count by API
  - 4xx and 5xx error counts
  - Average latency

- **DynamoDB Metrics**:
  - Consumed read/write capacity units
  - Throttled requests

- **Bedrock Metrics**:
  - Invocation count
  - Model invocation errors

Access the dashboard:

```bash
# Get dashboard URL
terraform output cloudwatch_dashboard_url

# Or navigate to:
# AWS Console → CloudWatch → Dashboards → claim-status-dashboard
```

## Alarms

Configured alarms will appear in CloudWatch Alarms:

```bash
# List all alarms
aws cloudwatch describe-alarms --alarm-name-prefix claim-status-

# Check alarm state
aws cloudwatch describe-alarms --query 'MetricAlarms[*].[AlarmName,StateValue]' --output table
```

To receive notifications:

1. Create an SNS topic
2. Update alarm definitions in `iac/terraform/observability.tf` to include `alarm_actions`

## Tracing (Optional)

For distributed tracing with AWS X-Ray:

1. Container Insights add-on includes X-Ray support
2. Configure application to export traces to X-Ray
3. View traces in AWS X-Ray console

## Container Insights Troubleshooting

### Check Container Insights Status

```bash
# Verify the EKS add-on is installed
aws eks describe-addon \
  --cluster-name claim-status-eks \
  --addon-name amazon-cloudwatch-observability \
  --region us-east-1

# Check CloudWatch agent pods
kubectl get pods -n amazon-cloudwatch

# View CloudWatch agent logs
kubectl logs -n amazon-cloudwatch -l app.kubernetes.io/name=cloudwatch-agent

# Check for log streams
aws logs describe-log-streams \
  --log-group-name /aws/containerinsights/claim-status-eks/application \
  --order-by LastEventTime --descending --max-items 5
```

### Common Issues

- **No metrics appearing**: Wait 5-10 minutes for initial metric collection
- **Add-on not installed**: Run `terraform apply` to install the add-on
- **Permission errors**: Verify EKS service role has CloudWatch permissions (managed automatically)
- **Old log group names**: If migrating from Fluent Bit, logs now go to `/aws/containerinsights/` not `/aws/eks/`

### Verify Log and Metric Collection

```bash
# Generate API traffic
curl $(terraform output -raw apigw_endpoint)/claims/CLM-2001

# Wait 30 seconds, then check CloudWatch
aws logs tail /aws/containerinsights/claim-status-eks/application --since 1m

# Check Container Insights dashboard
echo "https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#container-insights:performance/claim-status-eks"
```

## Cost Optimization

- Log retention set to 7 days (configurable in `observability.tf`)
- Container Insights costs ~$10/month per cluster (logs + metrics)
- Consider disabling performance metrics if only logs are needed
- Use CloudWatch Logs Insights sparingly (charged per GB scanned)
- Archive to S3 for long-term retention at lower cost

## Screenshots

Place observability screenshots in `observability/screenshots/`:

- `container-insights-cluster.png` - Container Insights cluster view
- `container-insights-performance.png` - Pod/node performance metrics
- `cloudwatch-dashboard.png` - Custom dashboard view
- `logs-insights.png` - Sample Logs Insights query
