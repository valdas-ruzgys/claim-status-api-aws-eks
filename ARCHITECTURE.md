# Architecture Documentation

## Executive Summary

This document provides comprehensive architectural reasoning for the Claim Status API, a GenAI-enabled microservice built with NestJS, deployed on Amazon EKS, and integrated with AWS managed services. The architecture emphasizes scalability, observability, security, and operational excellence while maintaining simplicity and cost-effectiveness.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Technology Choices & Rationale](#technology-choices--rationale)
- [Design Patterns](#design-patterns)
- [Infrastructure Decisions](#infrastructure-decisions)
- [Security Architecture](#security-architecture)
- [Observability Strategy](#observability-strategy)
- [Scalability & Performance](#scalability--performance)
- [Trade-offs & Constraints](#trade-offs--constraints)
- [Future Improvements](#future-improvements)

---

## Architecture Overview

### High-Level Architecture

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │
       │ HTTPS
       ▼
┌─────────────────────┐
│  API Gateway (HTTP) │  ← Managed entry point, TLS termination
└──────────┬──────────┘
           │ HTTP
           ▼
┌──────────────────────┐
│  Application Load    │  ← Regional load balancing, health checks
│  Balancer (ALB)      │
└──────────┬───────────┘
           │
           │ HTTP
           ▼
┌────────────────────────────────┐
│         EKS Cluster            │
│  ┌─────────────────────────┐  │
│  │  NestJS Pods (1-4)      │  │  ← Auto-scaling pods
│  │  ┌──────────────────┐   │  │
│  │  │  Claim Service   │   │  │
│  │  │  Bedrock Service │   │  │
│  │  │  DynamoDB Repo   │   │  │
│  │  │  S3 Repo         │   │  │
│  │  └──────────────────┘   │  │
│  └─────────────────────────┘  │
└────────────────────────────────┘
           │
           │ AWS SDK (IRSA)
           │
    ┌──────┴────────┬──────────────┬───────────────┐
    │               │              │               │
    ▼               ▼              ▼               ▼
┌──────────┐  ┌──────────┐  ┌─────────┐  ┌──────────────┐
│ DynamoDB │  │    S3    │  │ Bedrock │  │  CloudWatch  │
│  Claims  │  │  Notes   │  │  Nova   │  │  Logs/Metrics│
└──────────┘  └──────────┘  └─────────┘  └──────────────┘
```

### Component Responsibilities

1. **API Gateway**: Entry point, request routing, throttling, logging
2. **Application Load Balancer**: Regional distribution, health checking, SSL offloading
3. **EKS Pods**: Business logic, data transformation, AI orchestration
4. **DynamoDB**: Claim metadata storage (low-latency reads/writes)
5. **S3**: Notes storage (larger text blobs, versioned)
6. **Bedrock**: AI-powered summarization (Amazon Nova Micro)
7. **CloudWatch**: Centralized logging, metrics, alarms

---

## Technology Choices & Rationale

### 1. NestJS Framework

**Decision**: Use NestJS over Express, Fastify, or AWS Lambda

**Rationale**:

- **Modularity**: Built-in dependency injection and module system promotes clean architecture
- **TypeScript-first**: Strong typing reduces runtime errors and improves developer experience
- **Decorator-based**: Simplifies routing, validation, and middleware composition
- **Testing support**: Jest integration and testability by design
- **Production-ready**: Proven in enterprise applications with extensive middleware ecosystem

**Trade-offs**:

- Heavier than Express (larger container image)
- Steeper learning curve for developers unfamiliar with Angular-style DI
- More opinionated structure

### 2. Amazon EKS (Kubernetes)

**Decision**: Deploy on EKS rather than ECS, Lambda, or EC2 directly

**Rationale**:

- **Portability**: Kubernetes is cloud-agnostic; easier migration if needed
- **Advanced orchestration**: Built-in service discovery, health checks, rolling updates
- **Ecosystem**: Rich tooling for monitoring (Prometheus), tracing (Jaeger), service mesh (Istio)
- **Declarative configuration**: GitOps-friendly with kubectl and Helm
- **Auto-scaling**: Horizontal Pod Autoscaler (HPA) and Cluster Autoscaler

**Trade-offs**:

- Higher operational complexity vs. ECS or Lambda
- Cluster management overhead (patching, upgrades)
- Higher baseline cost for control plane ($0.10/hr per cluster)

**Why not Lambda?**:

- Bedrock invocations can take 2-5 seconds; Lambda cold starts would add latency
- Stateful connections to DynamoDB benefit from connection pooling
- Container deployment allows better local testing and CI/CD consistency

### 3. DynamoDB for Claims Metadata

**Decision**: Use DynamoDB over RDS (PostgreSQL/MySQL)

**Rationale**:

- **Scalability**: Automatic partitioning; handles millions of requests/second
- **Performance**: Single-digit millisecond latency at any scale
- **Serverless pricing**: Pay per request (on-demand mode) with no provisioning
- **High availability**: Multi-AZ replication built-in
- **Simple access pattern**: Key-value lookups by claim ID (no complex joins needed)

**Trade-offs**:

- Limited querying capabilities (no SQL, no ad-hoc queries)
- Single-table design requires careful planning for additional access patterns
- Eventual consistency for global secondary indexes

**Data Model**:

```typescript
ClaimItem {
  id: string (Partition Key)
  policyNumber: string
  amount: number
  customerName: string
  adjuster: string
  status: string
  lastUpdated: string (ISO8601)
}
```

### 4. S3 for Notes Storage

**Decision**: Store claim notes in S3 as JSON files, not in DynamoDB

**Rationale**:

- **Cost efficiency**: S3 storage ($0.023/GB) vs. DynamoDB ($0.25/GB for on-demand)
- **Size flexibility**: Notes can grow to megabytes without hitting DynamoDB 400KB item limit
- **Versioning**: S3 versioning provides audit trail of note changes
- **Archive capability**: Easy to move to Glacier for long-term retention
- **Separation of concerns**: Metadata in DynamoDB, content in S3

**Trade-offs**:

- Additional API call to fetch notes (adds ~20-50ms latency)
- Eventual consistency for versioned objects
- More complex code (two data sources instead of one)

**Storage Pattern**:

```
s3://claim-status-claim-notes/
  ├── CLM-2001.json
  ├── CLM-2002.json
  └── CLM-2003.json
```

### 5. Amazon Bedrock (Nova Micro)

**Decision**: Use Amazon Nova Micro model for summarization

**Rationale**:

- **Cost-effective**: Nova Micro is optimized for low cost ($0.035/1M input tokens)
- **Fast inference**: <1 second response time for typical claim summaries
- **Managed service**: No model hosting, auto-scaling, or infrastructure management
- **Regional availability**: Runs in us-east-1 without cross-region latency
- **AWS integration**: IAM-based access control, CloudWatch metrics

**Why Nova over Claude or GPT?**:

- **Price**: 10x cheaper than Claude-3 Haiku, 50x cheaper than GPT-4
- **Performance**: Sufficient quality for structured summarization tasks
- **Compliance**: All processing stays within AWS (important for insurance data)

**Prompt Engineering**:

```typescript
buildPrompt(claim, notes) {
  return [
    'You are a claims automation assistant. Produce concise outputs.',
    'Return JSON with keys: overallSummary, customerSummary, adjusterSummary, recommendedNextStep.',
    `Claim: ${JSON.stringify(claim)}`,
    `Notes: ${notes.join('\n')}`,
    'Keep customerSummary plain-language and empathetic.',
    'Keep adjusterSummary action-oriented and specific.',
    'recommendedNextStep must be one actionable sentence.'
  ].join('\n');
}
```

### 6. API Gateway HTTP API

**Decision**: Use API Gateway in front of ALB instead of direct ALB exposure

**Rationale**:

- **Managed throttling**: Built-in rate limiting and request quotas
- **Custom domain names**: Easy to attach Route 53 domain with ACM certificate
- **Usage plans**: Support for API keys and usage tracking per customer
- **CloudWatch integration**: Automatic logging and metrics
- **Future extensibility**: Can add Lambda authorizers, request/response transformations

**Trade-offs**:

- Additional hop adds ~5-10ms latency
- Extra cost ($1/million requests + data transfer)
- Complexity of two-tier architecture

**Why not REST API?**:

- HTTP API is 70% cheaper ($1 vs. $3.50 per million requests)
- Lower latency (average 10ms faster)
- Simpler configuration for basic proxy use case

---

## Design Patterns

### 1. Ports & Adapters (Hexagonal Architecture)

**Implementation**:

```
src/claims/
  ├── domain/claim.ts              # Core business entity
  ├── claims.service.ts            # Business logic
  ├── ports/
  │   ├── claim-repository.ts      # Interface
  │   ├── notes-repository.ts      # Interface
  │   └── summarization-provider.ts # Interface
  └── adapters/
      ├── dynamo.claim.repository.ts
      ├── s3.notes.repository.ts
      └── bedrock.service.ts
```

**Benefits**:

- **Testability**: Easy to mock repositories for unit tests
- **Flexibility**: Swap DynamoDB for PostgreSQL without changing business logic
- **Separation of concerns**: Domain logic independent of infrastructure

### 2. Dependency Injection

**NestJS Module Pattern**:

```typescript
@Module({
  imports: [DynamoModule, S3Module, BedrockModule],
  controllers: [ClaimsController],
  providers: [
    ClaimsService,
    {
      provide: 'ClaimRepository',
      useClass: DynamoClaimRepository
    }
  ]
})
export class ClaimsModule {}
```

**Benefits**:

- Loose coupling between components
- Simplified testing via provider overrides
- Clear dependency graph visible in module definitions

### 3. Repository Pattern

**Example**:

```typescript
interface ClaimRepository {
  findById(id: string): Promise<Claim | null>;
  save(claim: Claim): Promise<void>;
}

class DynamoClaimRepository implements ClaimRepository {
  async findById(id: string): Promise<Claim | null> {
    const result = await this.client.getItem({
      TableName: this.tableName,
      Key: { id: { S: id } }
    });
    return result.Item ? this.mapToEntity(result.Item) : null;
  }
}
```

**Benefits**:

- Abstracts data access complexity
- Enables testing without real database
- Supports multiple storage backends

### 4. Configuration Management

**Centralized Config Service**:

```typescript
@Injectable()
export class ConfigService {
  private readonly awsConfig: AwsConfig;

  constructor() {
    this.awsConfig = {
      region: process.env.AWS_REGION || 'us-east-1',
      claimsTableName: process.env.CLAIMS_TABLE_NAME || 'claims-table',
      notesBucket: process.env.NOTES_BUCKET || 'notes-bucket',
      bedrockModelId: process.env.BEDROCK_MODEL_ID || 'amazon.nova-micro-v1:0'
    };
  }
}
```

**Benefits**:

- Single source of truth for configuration
- Type-safe access to environment variables
- Defaults for local development

---

## Infrastructure Decisions

### 1. Infrastructure as Code (Terraform)

**Decision**: Use Terraform over CloudFormation or CDK

**Rationale**:

- **Multi-cloud**: Can manage non-AWS resources (GitHub, Datadog, etc.)
- **State management**: Remote state with locking prevents concurrent modifications
- **Modularity**: Reusable modules for VPC, EKS, etc.
- **Maturity**: Larger ecosystem and community support
- **Plan preview**: See changes before applying

**Structure**:

```
iac/terraform/
  ├── main.tf           # VPC, EKS, ECR, DynamoDB, S3, API Gateway
  ├── irsa.tf           # IAM Roles for Service Accounts
  ├── pipeline.tf       # CodePipeline, CodeBuild
  ├── observability.tf  # CloudWatch Logs, Dashboards, Alarms
  └── variables.tf      # Configurable parameters
```

### 2. Kubernetes Manifest Management

**Decision**: Use plain YAML manifests over Helm or Kustomize

**Rationale**:

- **Simplicity**: No templating engine to learn
- **Transparency**: Clear what will be deployed
- **GitOps-ready**: Easy to version control and review changes
- **CI/CD friendly**: Simple `kubectl apply` in pipelines

**When to migrate to Helm**:

- Need for multiple environments (dev, staging, prod) with different values
- Sharing charts with other teams
- Complex dependency management

### 3. IRSA (IAM Roles for Service Accounts)

**Decision**: Use IRSA over IAM instance roles or storing credentials

**Rationale**:

- **Least privilege**: Each pod can have different permissions
- **No credential management**: Temporary credentials injected by EKS
- **Auditing**: CloudTrail logs show which pod made which API call
- **Security**: Credentials never stored in environment variables or secrets

**Implementation**:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: claim-status-api
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789:role/claim-status-eks-pod-role
```

### 4. Single NAT Gateway

**Decision**: Use single NAT Gateway instead of one per AZ

**Rationale**:

- **Cost savings**: $32/month vs. $96/month (3 AZs)
- **Acceptable risk**: API calls to AWS services stay within AWS network
- **Outbound internet**: Only needed for pulling container images (ECR is VPC endpoint eligible)

**Trade-off**: If NAT Gateway AZ fails, pods in other AZs can't reach internet
**Mitigation**: Use VPC endpoints for ECR, DynamoDB, S3, Bedrock (eliminating need for NAT)

### 5. On-Demand DynamoDB Billing

**Decision**: Use on-demand vs. provisioned capacity

**Rationale**:

- **Predictable costs**: $1.25 per million write requests, $0.25 per million reads
- **No capacity planning**: Auto-scales to any workload
- **Better for spiky workloads**: Insurance claims spike after disasters
- **No throttling risk**: Instant scaling to handle traffic spikes

**When to switch to provisioned**:

- Sustained, predictable traffic >1M requests/day
- Can save 40-60% with reserved capacity

---

## Security Architecture

### 1. Network Security

**VPC Configuration**:

- **Private subnets**: EKS nodes run in private subnets (no direct internet access)
- **Public subnets**: ALB targets in public subnets for internet-facing traffic
- **Security groups**:
  - ALB SG: Allow 80/443 from 0.0.0.0/0
  - EKS node SG: Allow 3000 from ALB SG only
  - No SSH access (use AWS Systems Manager Session Manager for debugging)

**Network Flow**:

```
Internet → API Gateway → ALB (public subnet) → EKS Pods (private subnet) → AWS Services (VPC endpoints)
```

### 2. IAM Least Privilege

**Pod Permissions** (via IRSA):

```json
{
  "Effect": "Allow",
  "Action": [
    "bedrock:InvokeModel",
    "dynamodb:GetItem",
    "dynamodb:PutItem",
    "s3:GetObject",
    "s3:PutObject"
  ],
  "Resource": [
    "arn:aws:dynamodb:*:*:table/claim-status-claims",
    "arn:aws:s3:::claim-status-claim-notes/*"
  ]
}
```

**No permissions for**:

- DeleteItem/DeleteObject (no destructive operations)
- Wildcard resources
- Admin actions (CreateTable, DeleteBucket)

### 3. Secrets Management

**Current State**: No secrets stored (all AWS API calls use IAM)

**Future Enhancements**:

- AWS Secrets Manager for third-party API keys
- Kubernetes External Secrets Operator for GitOps workflows
- Encryption at rest for DynamoDB and S3 (using AWS KMS)

### 4. Container Security

**Image Scanning**:

- ECR scan-on-push enabled (AWS Inspector)
- Scans for CVEs in OS packages and application dependencies
- Fail pipeline if CRITICAL vulnerabilities found

**Runtime Security**:

- Read-only root filesystem (prevents malware persistence)
- Non-root user (UID 1000)
- Drop all Linux capabilities except NET_BIND_SERVICE

**Recommended additions**:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  readOnlyRootFilesystem: true
  capabilities:
    drop: [ALL]
```

### 5. Data Protection

**At Rest**:

- DynamoDB: Enable encryption with AWS managed keys (KMS)
- S3: Enable default encryption (SSE-S3 or SSE-KMS)
- EBS volumes: Encrypted with AWS managed keys

**In Transit**:

- API Gateway → ALB: HTTPS (TLS 1.2+)
- ALB → Pods: HTTP (within VPC, acceptable for non-PII)
- Pods → AWS services: TLS 1.2 (enforced by AWS SDKs)

**PII Handling**:

- Customer names are not encrypted (low sensitivity)
- Recommend field-level encryption for SSNs, medical records if added

---

## Observability Strategy

### 1. Logging

**CloudWatch Logs**:

- **EKS control plane logs**: API server, audit, authenticator
- **Application logs**: Structured JSON logs from NestJS
- **ALB access logs**: HTTP requests, response times, status codes

**Log Aggregation**:

```typescript
logger.log({
  level: 'info',
  claimId: 'CLM-2001',
  action: 'summarize',
  duration: 1234,
  model: 'amazon.nova-micro-v1:0'
});
```

**Retention**:

- Application logs: 7 days (configurable)
- ALB logs: 30 days
- Control plane logs: 90 days (compliance)

### 2. Metrics

**CloudWatch Dashboards**:

- API Gateway: Request count, latency (p50, p95, p99), error rate
- DynamoDB: Consumed capacity, throttles
- Bedrock: Invocations, errors, latency
- EKS: Pod CPU/memory, node capacity

**Custom Metrics** (recommended):

```typescript
cloudwatch.putMetric({
  namespace: 'ClaimStatusAPI',
  metricName: 'SummarizeLatency',
  value: duration,
  unit: 'Milliseconds',
  dimensions: { Model: 'nova-micro' }
});
```

### 3. Alarms

**Pre-configured Alarms**:

- **High 5xx rate**: >10 errors in 5 minutes
- **High latency**: p95 >1 second
- **DynamoDB throttles**: >5 throttles/minute
- **Bedrock errors**: >1 error/minute

**Escalation**:

- SNS topic → Email/Slack (requires configuration)
- PagerDuty integration for on-call rotation

### 4. Tracing (Future)

**AWS X-Ray Integration**:

- Deploy ADOT collector as DaemonSet
- Instrument NestJS with `aws-xray-sdk`
- Trace flow: API Gateway → ALB → NestJS → DynamoDB/S3/Bedrock

**Benefits**:

- End-to-end request visualization
- Identify bottlenecks (which service is slow?)
- Correlation of logs and traces

---

## Scalability & Performance

### 1. Horizontal Scaling

**Pod Auto-Scaling** (HPA):

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: claim-status-api
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: claim-status-api
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

**Cluster Auto-Scaling**:

- Cluster Autoscaler watches for pending pods
- Adds nodes when CPU/memory pressure detected
- Scales down during low traffic

### 2. Performance Optimizations

**Connection Pooling**:

```typescript
const dynamoClient = new DynamoDBClient({
  maxAttempts: 3,
  requestTimeout: 3000,
  connectionTimeout: 1000
});
```

**S3 Caching** (future):

```typescript
const cache = new NodeCache({ stdTTL: 300 }); // 5-minute TTL
async getNotes(claimId: string) {
  const cached = cache.get(claimId);
  if (cached) return cached;
  const notes = await s3.getObject(...);
  cache.set(claimId, notes);
  return notes;
}
```

**Bedrock Timeout**:

- Set 10-second timeout for Bedrock invocations
- Return partial summary if timeout exceeded
- Log timeout events for monitoring

### 3. Database Performance

**DynamoDB Best Practices**:

- Use partition key (claim ID) for even distribution
- Avoid hot partitions (no sequential IDs)
- Enable point-in-time recovery for backups

**Potential Bottlenecks**:

- Reading large S3 notes files (>1MB) → Use streaming or pagination
- Bedrock rate limits (100 TPS) → Implement exponential backoff

---

## Trade-offs & Constraints

### 1. Cost vs. Availability

**Decision**: Single NAT Gateway, 2-node EKS cluster

**Trade-off**:

- Saves $64/month (NAT) + $150/month (nodes)
- Reduces availability from 99.95% to 99.9%

**Acceptable because**:

- Not mission-critical (claims can wait 5 minutes)
- Easy to scale up for production

### 2. Latency vs. Cost

**Decision**: API Gateway + ALB instead of direct ALB

**Trade-off**:

- Adds 5-10ms latency
- Costs $1/million requests

**Acceptable because**:

- Gain throttling, usage tracking, custom domains
- 10ms is <1% of total request time (Bedrock takes 1-2 seconds)

### 3. Complexity vs. Flexibility

**Decision**: EKS instead of Lambda or ECS

**Trade-off**:

- Higher operational complexity (Kubernetes learning curve)
- More upfront setup (networking, RBAC, add-ons)

**Acceptable because**:

- Portability to other clouds (avoid vendor lock-in)
- Rich ecosystem for observability, service mesh, etc.
- Better for long-running connections and connection pooling

### 4. Consistency vs. Latency

**Decision**: Separate DynamoDB and S3 calls instead of storing everything in DynamoDB

**Trade-off**:

- Two API calls add 20-50ms
- Potential inconsistency if S3 write fails after DynamoDB write

**Mitigation**:

- Write to DynamoDB first (critical metadata)
- S3 write is idempotent (retry safe)
- Use S3 event notifications to trigger cleanup if needed

---

## Future Improvements

### 1. Multi-Region Deployment

**Why**: Disaster recovery, lower latency for global users

**Implementation**:

- DynamoDB Global Tables for cross-region replication
- S3 Cross-Region Replication (CRR)
- Route 53 geo-routing to nearest API Gateway
- Active-active or active-passive setup

**Estimated cost**: +100% (duplicate infrastructure)

### 2. GraphQL API

**Why**: Flexible querying for frontend applications

**Implementation**:

- Add Apollo Server to NestJS
- Schema-first approach with code generation
- DataLoader for N+1 query optimization

**Trade-offs**:

- Increased complexity
- API Gateway doesn't support GraphQL subscriptions (need ALB directly)

### 3. Event-Driven Architecture

**Why**: Decouple claim creation from summarization

**Implementation**:

```
Claim Created → SNS Topic → Lambda (async summarize) → DynamoDB update
```

**Benefits**:

- Faster API response (don't wait for Bedrock)
- Retry failed summarizations automatically
- Better scalability (Lambda handles bursts)

### 4. Service Mesh (Istio)

**Why**: Advanced traffic management, mTLS, observability

**Features**:

- Circuit breaking for Bedrock failures
- Mutual TLS between all services
- Distributed tracing without code changes
- Canary deployments (5% traffic to new version)

**Trade-offs**:

- Adds complexity (sidecar proxies)
- Increases resource usage (15-20% CPU overhead)

### 5. Cost Optimization

**Spot Instances**:

- Use Spot Instances for EKS nodes (70% cost savings)
- Combine with On-Demand for baseline capacity
- Implement pod disruption budgets for graceful eviction

**Reserved Instances**:

- Commit to 1-year DynamoDB reserved capacity (save 40%)
- Only if traffic is predictable and sustained

**S3 Intelligent Tiering**:

- Automatically move old notes to cheaper storage classes
- Lifecycle policy: Move to Glacier after 90 days

---

## Conclusion

This architecture balances **simplicity**, **cost-effectiveness**, and **production-readiness**. Key principles:

1. **Managed services first**: Leverage AWS-managed DynamoDB, S3, Bedrock, EKS to minimize operational burden
2. **Modularity**: Ports & adapters pattern allows swapping components (e.g., switch to PostgreSQL)
3. **Observability**: CloudWatch Logs, Metrics, and Dashboards provide visibility into system health
4. **Security**: IRSA, private subnets, least-privilege IAM, and image scanning
5. **Scalability**: Horizontal pod autoscaling and DynamoDB on-demand capacity

The architecture is designed for **iterative improvement** - start simple, monitor usage, and add complexity (multi-region, caching, event-driven) only when needed.
