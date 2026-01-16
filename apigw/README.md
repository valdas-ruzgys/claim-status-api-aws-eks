# API Gateway Configuration

This folder contains exported configuration files for the Claims Status API Gateway.

## Overview

- **API Type**: HTTP API (API Gateway v2)
- **API ID**: z9h8kzgrea
- **Endpoint**: https://z9h8kzgrea.execute-api.us-east-1.amazonaws.com
- **Region**: us-east-1
- **Backend**: EKS Application Load Balancer

## Configuration Files

### Core Configuration

- **api-configuration.json**: Main API Gateway settings and metadata
- **stage-configuration.json**: Stage-level settings including auto-deploy, logging, and throttling
- **routes.json**: Route definitions (currently using $default catch-all route)
- **integration-config.json**: Backend integration configuration for EKS ALB

### Policies

- **resource-policy.json**: IAM resource policy controlling API access (currently allows public access)
- **cors-configuration.json**: Cross-Origin Resource Sharing (CORS) settings
- **throttling-policy.json**: Rate limiting and burst limit configurations per route

## Architecture

```
Client Request
    ↓
API Gateway (z9h8kzgrea)
    ↓
HTTP_PROXY Integration
    ↓
Application Load Balancer (k8s-default-claimsta-3fc9386aa2-1027118312)
    ↓
EKS Pods (claim-status-api)
    ↓
Backend Services (DynamoDB, S3, Bedrock)
```

## Routes

| Route Key  | Method | Backend | Description                                |
| ---------- | ------ | ------- | ------------------------------------------ |
| `$default` | ANY    | EKS ALB | Proxies all requests to Kubernetes service |

### API Endpoints (via $default route)

- `GET /claims` - List all claims
- `GET /claims/{claimId}` - Get specific claim
- `POST /claims` - Create new claim
- `POST /claims/{claimId}/summarize` - Generate AI summary using Amazon Nova Micro

## Throttling Limits

### Default Stage Limits

- **Burst Limit**: 5,000 requests
- **Rate Limit**: 2,000 requests/second

### Recommended Per-Route Limits

- `GET /claims/{claimId}`: 50 req/s (burst: 100)
- `POST /claims`: 25 req/s (burst: 50)
- `POST /claims/{claimId}/summarize`: 10 req/s (burst: 20) - Lower due to Bedrock API costs

## Security Considerations

### Current Configuration

- **Public Access**: API is publicly accessible without authentication
- **CORS**: Enabled for all origins (suitable for public API)
- **Encryption**: TLS 1.2+ enforced by API Gateway

### Recommended Enhancements

1. **API Keys**: Implement API key authentication
2. **AWS WAF**: Add Web Application Firewall for DDoS protection
3. **Resource Policy**: Restrict access by IP range or VPC
4. **Request Validation**: Add request/response validation models
5. **Lambda Authorizer**: Implement custom authorization logic

## Monitoring

### CloudWatch Metrics

- `4xx` - Client errors
- `5xx` - Server errors
- `Count` - Total requests
- `Latency` - Request latency
- `IntegrationLatency` - Backend response time

### Access Logs

Logs are sent to: `/aws/apigateway/claim-status-api`

Format: `$context.requestId $context.error.message $context.error.messageString`

## Cost Optimization

### Current Setup

- HTTP API pricing: $1.00 per million requests
- No data transfer charges within AWS (API Gateway → ALB in same region)

### Optimization Tips

1. **Caching**: Enable caching for GET requests (reduces backend calls)
2. **Compression**: Enable payload compression for responses > 1KB
3. **Throttling**: Implement per-client throttling to prevent abuse

## Terraform Management

All API Gateway resources are managed via Terraform in `iac/terraform/main.tf`:

```hcl
resource "aws_apigatewayv2_api" "http"
resource "aws_apigatewayv2_integration" "eks"
resource "aws_apigatewayv2_route" "claims"
resource "aws_apigatewayv2_stage" "default"
```

## Testing

### Health Check

```bash
curl https://z9h8kzgrea.execute-api.us-east-1.amazonaws.com/claims
```

### Get Claim

```bash
curl https://z9h8kzgrea.execute-api.us-east-1.amazonaws.com/claims/CLM-2001
```

### Generate Summary

```bash
curl -X POST https://z9h8kzgrea.execute-api.us-east-1.amazonaws.com/claims/CLM-2001/summarize
```

## Disaster Recovery

### Backup Strategy

- Configuration is version-controlled in this repository
- Terraform state includes all API Gateway settings
- Can recreate API Gateway from Terraform code

### Recovery Steps

1. Apply Terraform configuration: `terraform apply`
2. Update DNS/client configurations with new API ID if changed
3. Verify integration with EKS ALB
4. Test all routes

## Related Documentation

- [Main README](../README.md)
- [Architecture Documentation](../ARCHITECTURE.md)
- [Observability Guide](../observability/README.md)
- [Terraform IaC](../iac/terraform/)

## Support

For issues or questions:

1. Check CloudWatch Logs: `/aws/apigateway/claim-status-api`
2. Review CloudWatch Metrics dashboard
3. Verify EKS ALB health: `kubectl get ingress -n default`
4. Check backend pod status: `kubectl get pods -n default`
