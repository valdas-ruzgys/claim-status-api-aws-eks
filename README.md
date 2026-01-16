# Claim Status API (NestJS + EKS)

GenAI-enabled claim status service using NestJS, Amazon Bedrock, DynamoDB, S3, EKS, and API Gateway. Includes IaC, pipelines, and observability scaffolding.

## Contents

- **Architecture**: [ARCHITECTURE.md](ARCHITECTURE.md) - Comprehensive architectural decisions and reasoning
- Service code: [src](src) with NestJS modules and [src/Dockerfile](src/Dockerfile)
- Mocks: [mocks/claims.json](mocks/claims.json), [mocks/notes.json](mocks/notes.json)
- IaC: [iac/terraform](iac/terraform) (EKS, VPC, ECR, DynamoDB, S3, API Gateway, IRSA, CI/CD pipeline)
- K8s manifests: [k8s-manifests](k8s-manifests)
- CI/CD buildspec: [pipelines/buildspec.yml](pipelines/buildspec.yml)
- Security scans: [scans/README.md](scans/README.md)
- Observability: [observability/README.md](observability/README.md)

## Architecture

- API: NestJS, ports/adapters for claims repository, notes repository, and Bedrock summarizer.
- Data: DynamoDB for claim metadata; S3 for notes.
- GenAI: Amazon Bedrock (amazon.nova-micro-v1:0 by default) for multi-view summaries.
- Platform: EKS (EC2 managed node groups) exposed via ALB Ingress → API Gateway HTTP API proxy.
- CI/CD: CodePipeline → CodeBuild → ECR push → K8s deploy.
- Security: ECR scan-on-push (Inspector), IAM least-privilege scaffold, placeholders for findings.
- Observability: CloudWatch Container Insights (automated logs + metrics collection), Dashboards, Alarms (5xx rate, latency, DynamoDB throttles, Bedrock errors); X-Ray tracing support.

## Running locally (mock mode)

1. Install Node.js 20 and npm.
2. `npm ci`
3. `USE_MOCKS=true npm run start:dev`
4. Test endpoints:
   - `GET http://localhost:3000/claims/CLM-1001`
   - `POST http://localhost:3000/claims/CLM-1001/summarize`
   - `POST http://localhost:3000/claims` (create new claim)
5. Populate test data:
   - `npm run populate:data` (creates 10 sample claims via API)

## Configuration

Environment variables (see [src/config/config.service.ts](src/config/config.service.ts)):

- `AWS_REGION` (default `us-east-1`)
- `CLAIMS_TABLE_NAME` (DynamoDB table)
- `NOTES_BUCKET` (S3 bucket for notes files named <claimId>.json)
- `BEDROCK_MODEL_ID` (default amazon.nova-micro-v1:0)
- `BEDROCK_REGION` (optional override)
- `USE_MOCKS` (`true` for local mock data from [mocks](mocks))

## Build and containerize

- `npm run build`
- `docker build -t claim-status-api:local -f src/Dockerfile .`

## Scripts

- `npm run test:lint` — ESLint over src
- `npm run test:unit` — Jest (passes even if no tests present)
- `npm run test:smoke` — curl-based smoke hits `/claims/{id}` and `/claims/{id}/summarize` (expects service running; set `BASE_URL` and `CLAIM_ID` to override)
- `npm run populate:data` — populate test claims data via API (set `BASE_URL` to override default `http://localhost:3000`)
- `npm run deploy:infra` — `terraform apply` in `iac/terraform`
- `npm run destroy:infra` — `terraform destroy` in `iac/terraform`
- `npm run deploy:k8s` — apply manifests in `k8s-manifests`
- `npm run deploy:all` — automated full deployment (infrastructure + Kubernetes + ALB)

## Deployment

### Automated Deployment (Recommended)

Use the automated deployment script that handles all infrastructure provisioning, Docker build, and Kubernetes deployment:

```bash
# Set your AWS profile if needed
export AWS_PROFILE=my-profile

# Run the automated deployment
npm run deploy:all
# or directly: ./scripts/deploy.sh
```

The script will:

1. Verify prerequisites (AWS CLI, Terraform, Docker, kubectl, Helm)
2. Check CodeStar Connection (prompts if manual authorization needed)
3. Initialize and apply Terraform infrastructure (including Container Insights, CloudWatch log groups, dashboards, alarms)
4. Configure kubectl for EKS cluster
5. Build and push Docker image to ECR
6. Update Kubernetes manifests with ECR image and IAM role ARNs
7. Deploy application Kubernetes manifests (Container Insights automatically collects logs and metrics)
8. Install AWS Load Balancer Controller via Helm
9. Wait for Application Load Balancer provisioning
10. Update terraform.tfvars with ALB DNS and apply final integration
11. Display API Gateway endpoint, CloudWatch dashboard, and Container Insights links

### Manual Kubernetes Deployment

If you prefer manual steps:

1. Push image to ECR and update [k8s-manifests/deployment.yaml](k8s-manifests/deployment.yaml) `image` field.
2. Apply manifests:
   ```bash
   # Deploy application
   kubectl apply -f k8s-manifests/serviceaccount.yaml
   kubectl apply -f k8s-manifests/deployment.yaml
   kubectl apply -f k8s-manifests/ingress.yaml
   # Container Insights automatically collects logs and metrics
   ```
3. Install AWS Load Balancer Controller:
   ```bash
   helm repo add eks https://aws.github.io/eks-charts
   helm repo update
   helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
     -n kube-system \
     --set clusterName=claim-status-eks \
     --set serviceAccount.create=false \
     --set serviceAccount.name=aws-load-balancer-controller
   ```
4. Get ALB DNS:
   ```bash
   kubectl get ingress claim-status-api -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
   ```
5. Update `terraform.tfvars` with ingress_alb_dns and run `terraform apply`

## Infrastructure (Terraform)

### Prerequisites

1. **Install required tools:**
   - Terraform (>= 1.5.0): `brew tap hashicorp/tap && brew install hashicorp/tap/terraform` (macOS) or download from https://terraform.io
   - AWS CLI: `brew install awscli` (macOS) or download from https://aws.amazon.com/cli/
   - Docker: Download from https://docker.com
   - kubectl: `brew install kubectl` (macOS) or follow https://kubernetes.io/docs/tasks/tools/
   - Helm: `brew install helm` (macOS) or download from https://helm.sh

2. **Configure AWS CLI:**

   ```bash
   aws configure --profile my-profile
   # Or use default profile: aws configure
   ```

3. **Verify access:**

   ```bash
   aws sts get-caller-identity --profile my-profile
   ```

4. **Set AWS profile (if using named profile):**
   ```bash
   export AWS_PROFILE=my-profile
   ```

### Quick Start (Automated)

See [Deployment](#deployment) section above for automated deployment using `npm run deploy:all`.

### Manual Setup Steps

1. Navigate to Terraform directory:

   ```bash
   cd iac/terraform
   ```

2. Initialize Terraform (downloads providers):

   ```bash
   terraform init
   ```

3. Create a CodeStar Connection for GitHub:
   - AWS Console → Developer Tools → Connections → Create connection
   - Provider: GitHub
   - Connection name: `claim-status-github`
   - Click "Connect to GitHub" → Authorize and install AWS Connector app
   - Copy the connection ARN after creation

4. Create a `terraform.tfvars` file with your values:

   ```hcl
   region                = "us-east-1"
   name                  = "claim-status"
   worker_instance_type  = "t3.small"
   github_connection_arn = "arn:aws:codeconnections:us-east-1:123456789012:connection/abc-def-123"
   github_owner          = "your-github-org"
   github_repo           = "your-repo-name"
   repo_branch           = "main"
   ingress_alb_dns       = ""  # Leave empty on first apply; update after EKS ingress is deployed
   ```

5. Review planned changes:

   ```bash
   terraform plan
   ```

6. Apply infrastructure (first pass without ingress_alb_dns):

   ```bash
   terraform apply
   ```

7. Build and push Docker image:

   ```bash
   # Get ECR login token
   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $(terraform output -raw ecr_repo_url | cut -d'/' -f1)

   # Build and tag image
   docker build -t claim-status-api:latest -f ../../src/Dockerfile ../..
   docker tag claim-status-api:latest $(terraform output -raw ecr_repo_url):latest

   # Push to ECR
   docker push $(terraform output -raw ecr_repo_url):latest
   ```

8. Configure kubectl and deploy K8s manifests:

   ```bash
   aws eks update-kubeconfig --name claim-status-eks --region us-east-1

   # Update manifests with terraform outputs
   POD_ROLE_ARN=$(terraform output -raw pod_role_arn)
   ECR_IMAGE=$(terraform output -raw ecr_repo_url):latest

   sed -i.bak "s|eks.amazonaws.com/role-arn:.*|eks.amazonaws.com/role-arn: $POD_ROLE_ARN|" ../../k8s-manifests/serviceaccount.yaml
   sed -i.bak "s|image:.*claim-status-api.*|image: $ECR_IMAGE|" ../../k8s-manifests/deployment.yaml

   kubectl apply -f ../../k8s-manifests/
   ```

9. Install AWS Load Balancer Controller:

   ```bash
   helm repo add eks https://aws.github.io/eks-charts
   helm repo update

   CONTROLLER_ROLE_ARN=$(terraform output -raw aws_load_balancer_controller_role_arn)

   helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
     -n kube-system \
     --set clusterName=claim-status-eks \
     --set serviceAccount.create=false \
     --set serviceAccount.name=aws-load-balancer-controller \
     --set region=us-east-1 \
     --set vpcId=$(terraform output -raw vpc_id) \
     --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$CONTROLLER_ROLE_ARN \
     --wait
   ```

10. Wait for ALB and update terraform.tfvars:

    ```bash
    # Wait for ALB DNS (takes 2-3 minutes)
    kubectl get ingress claim-status-api -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

    # Update terraform.tfvars with the ALB DNS
    # ingress_alb_dns = "k8s-claim-xxxx.us-east-1.elb.amazonaws.com"

    # Apply final integration
    terraform apply
    ```

11. Get API Gateway endpoint:
    ```bash
    terraform output apigw_endpoint
    ```

### Terraform Resources

- Files in [iac/terraform](iac/terraform) create VPC, EKS (IRSA), ECR, DynamoDB, S3, API Gateway HTTP proxy, CodePipeline, and CodeBuild.
- Main files: `main.tf`, `pipeline.tf`, `irsa.tf`, `variables.tf`
- Variables: `region`, `name`, `worker_instance_type`, `ingress_alb_dns`, `github_connection_arn`, `github_owner`, `github_repo`, `repo_branch`

### Cleanup

```bash
cd iac/terraform
terraform destroy
```

## API contract

- `GET /claims/health` → health check
- `GET /claims/{id}` → get claim by ID
- `POST /claims` → create a new claim (body: `{ policyNumber, amount, customerName, adjuster, status?, id?, lastUpdated?, notes? }`)
- `POST /claims/{id}/summarize` → generate AI-powered summaries using Bedrock

**Example: Create a claim**

```bash
curl -X POST http://localhost:3000/claims \
  -H "Content-Type: application/json" \
  -d '{
    "policyNumber": "POL-9999",
    "amount": 5000,
    "customerName": "John Doe",
    "adjuster": "Jane Smith",
    "status": "OPEN"
  }'
```

**Example: Create a claim with notes**

```bash
curl -X POST http://localhost:3000/claims \
  -H "Content-Type: application/json" \
  -d '{
    "policyNumber": "POL-9999",
    "amount": 5000,
    "customerName": "John Doe",
    "adjuster": "Jane Smith",
    "status": "OPEN",
    "notes": [
      "Initial inspection completed.",
      "Customer provided all required documentation.",
      "Pending contractor estimate."
    ]
  }'
```

**Example: Generate AI summary**

```bash
curl -X POST http://localhost:3000/claims/CLM-2001/summarize

# Response:
{
  "claimId": "CLM-2001",
  "overallSummary": "Property damage claim for water damage with pending documentation review.",
  "customerSummary": "Your claim is being actively reviewed. We are awaiting additional documentation from the inspection team.",
  "adjusterSummary": "Claim shows water damage to kitchen and basement. Inspection report pending. Recommend site visit within 48 hours.",
  "recommendedNextStep": "Schedule on-site inspection and request contractor estimates for repair costs."
}
```

## CI/CD

The project includes a fully automated CI/CD pipeline that:

1. Monitors the GitHub repository for changes
2. Runs linting and tests
3. Builds a Docker image and pushes to ECR
4. Automatically deploys the new image to EKS using `kubectl rollout`

### Pipeline Architecture

- **CodePipeline** orchestrates the workflow with Terraform in [iac/terraform/pipeline.tf](iac/terraform/pipeline.tf)
- **CodeBuild** executes [pipelines/buildspec.yml](pipelines/buildspec.yml) which:
  - Installs Node.js 20 and kubectl
  - Runs `npm run lint` and `npm test`
  - Builds and pushes Docker image to ECR
  - Updates the EKS deployment with the new image
  - Waits for rollout completion

### Setup

1. Create a CodeStar connection (AWS Console → Developer Tools → Connections):
   - Provider: GitHub
   - Connection name: `claim-status-github`
   - Authorize the GitHub repo
2. Apply Terraform with pipeline variables:

   ```bash
   cd iac/terraform
   terraform apply \
     -var "github_connection_arn=arn:aws:codeconnections:..." \
     -var "github_owner=your-org" \
     -var "github_repo=your-repo" \
     -var "repo_branch=main"
   ```

3. Push code to trigger the pipeline:
   ```bash
   git push origin main
   ```

### Pipeline Permissions

The CodeBuild role has EKS cluster admin access to perform deployments. This is configured via:

- `aws_eks_access_entry` - Grants CodeBuild role access to the cluster
- `AmazonEKSClusterAdminPolicy` - Allows full kubectl operations

### Monitoring

View pipeline execution:

```bash
# Check pipeline status
aws codepipeline get-pipeline-state --name claim-status-pipeline

# View build logs
aws codebuild list-builds-for-project --project-name claim-status-build
```

## Security

- ECR image scanning via Inspector (enabled in [iac/terraform/main.tf](iac/terraform/main.tf)).
- Record screenshots/links in [scans](scans).
- Recommend enabling Security Hub; wire Inspector findings to Hub and notifications.

## Observability

- See queries and dashboard notes in [observability/README.md](observability/README.md).
- Export app logs to CloudWatch via fluent-bit or ADOT sidecar.

## GenAI prompt (Bedrock)

Prompt template used in [src/genai/bedrock.service.ts](src/genai/bedrock.service.ts): concise JSON instruction requiring `overallSummary`, `customerSummary`, `adjusterSummary`, and `recommendedNextStep` based on claim metadata and notes.

## Assumptions and trade-offs

- ALB Ingress is used to front the service; API Gateway proxies to ALB DNS.
- Mock mode supports local testing without AWS resources.
- Bedrock output parsing expects JSON but falls back to raw text for resiliency.

## Next steps

- Add integration tests hitting a mocked Bedrock runtime.
- Harden IAM: scoped roles for service account via IRSA.
- Add HPA and PodDisruptionBudget for production.
