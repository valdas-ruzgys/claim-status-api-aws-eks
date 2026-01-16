#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Claim Status API - Full Deployment${NC}"
echo -e "${GREEN}========================================${NC}"

# Check prerequisites
echo -e "\n${YELLOW}Checking prerequisites...${NC}"
command -v aws >/dev/null 2>&1 || { echo -e "${RED}AWS CLI is required but not installed.${NC}" >&2; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo -e "${RED}Terraform is required but not installed.${NC}" >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}kubectl is required but not installed.${NC}" >&2; exit 1; }
command -v helm >/dev/null 2>&1 || { echo -e "${RED}Helm is required but not installed. Run: brew install helm${NC}" >&2; exit 1; }

# Verify AWS credentials
echo -e "${YELLOW}Verifying AWS credentials...${NC}"
aws sts get-caller-identity >/dev/null || { echo -e "${RED}AWS credentials not configured. Run: export AWS_PROFILE=your-profile${NC}" >&2; exit 1; }

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=${AWS_REGION:-us-east-1}
echo -e "${GREEN}✓ AWS Account: ${ACCOUNT_ID}, Region: ${REGION}${NC}"

# Configuration variables
GITHUB_OWNER="${GITHUB_OWNER:-valdas-ruzgys}"
GITHUB_REPO="${GITHUB_REPO:-claim-status-api-aws-eks}"
REPO_BRANCH="${REPO_BRANCH:-main}"
CONNECTION_NAME="claim-status-github"
PROJECT_NAME="claim-status"
WORKER_INSTANCE_TYPE="t3.small"

echo -e "\n${YELLOW}Configuration:${NC}"
echo "  GitHub Owner: ${GITHUB_OWNER}"
echo "  GitHub Repo: ${GITHUB_REPO}"
echo "  Branch: ${REPO_BRANCH}"
echo "  Worker Instance: ${WORKER_INSTANCE_TYPE}"

# Step 1: Create or get CodeStar Connection
echo -e "\n${YELLOW}Step 1: Checking CodeStar Connection...${NC}"
CONNECTION_ARN=$(aws codeconnections list-connections --region ${REGION} \
  --query "Connections[?ConnectionName=='${CONNECTION_NAME}'].ConnectionArn" \
  --output text 2>/dev/null || echo "")

if [ -z "$CONNECTION_ARN" ]; then
  echo -e "${YELLOW}Creating CodeStar Connection...${NC}"
  CONNECTION_ARN=$(aws codeconnections create-connection \
    --provider-type GitHub \
    --connection-name ${CONNECTION_NAME} \
    --region ${REGION} \
    --query ConnectionArn --output text)
  echo -e "${GREEN}✓ Created connection: ${CONNECTION_ARN}${NC}"
  
  echo -e "${RED}⚠ MANUAL STEP REQUIRED:${NC}"
  echo -e "${YELLOW}1. Go to: https://console.aws.amazon.com/codesuite/settings/connections?region=${REGION}${NC}"
  echo -e "${YELLOW}2. Find connection: ${CONNECTION_NAME}${NC}"
  echo -e "${YELLOW}3. Click 'Update pending connection' and authorize GitHub${NC}"
  echo -e "${YELLOW}4. Press Enter when done...${NC}"
  read -r
else
  echo -e "${GREEN}✓ Found existing connection: ${CONNECTION_ARN}${NC}"
  
  # Check connection status
  CONNECTION_STATUS=$(aws codeconnections get-connection \
    --connection-arn ${CONNECTION_ARN} \
    --region ${REGION} \
    --query ConnectionStatus --output text)
  
  if [ "$CONNECTION_STATUS" != "AVAILABLE" ]; then
    echo -e "${RED}⚠ Connection status: ${CONNECTION_STATUS}${NC}"
    echo -e "${YELLOW}Please authorize the connection in AWS Console and press Enter...${NC}"
    read -r
  else
    echo -e "${GREEN}✓ Connection is authorized${NC}"
  fi
fi

# Step 2: Create terraform.tfvars
echo -e "\n${YELLOW}Step 2: Creating terraform.tfvars...${NC}"
cd iac/terraform
cat > terraform.tfvars <<EOF
region                 = "${REGION}"
name                   = "${PROJECT_NAME}"
worker_instance_type   = "${WORKER_INSTANCE_TYPE}"
github_connection_arn  = "${CONNECTION_ARN}"
github_owner           = "${GITHUB_OWNER}"
github_repo            = "${GITHUB_REPO}"
repo_branch            = "${REPO_BRANCH}"
ingress_alb_dns        = ""
EOF
echo -e "${GREEN}✓ Created terraform.tfvars${NC}"

# Step 3: Initialize Terraform
echo -e "\n${YELLOW}Step 3: Initializing Terraform...${NC}"
terraform init -upgrade
echo -e "${GREEN}✓ Terraform initialized${NC}"

# Step 4: Apply infrastructure (first pass without ALB DNS)
echo -e "\n${YELLOW}Step 4: Deploying infrastructure (this may take 10-15 minutes)...${NC}"
terraform apply -auto-approve
echo -e "${GREEN}✓ Infrastructure deployed${NC}"

# Get outputs
CLUSTER_NAME=$(terraform output -raw cluster_name)
ECR_REPO=$(terraform output -raw repository_url)
POD_ROLE_ARN=$(terraform output -raw pod_role_arn)
CLAIMS_TABLE=$(terraform output -raw claims_table)
NOTES_BUCKET=$(terraform output -raw notes_bucket)

echo -e "${GREEN}Outputs:${NC}"
echo "  Cluster: ${CLUSTER_NAME}"
echo "  ECR: ${ECR_REPO}"
echo "  Pod Role: ${POD_ROLE_ARN}"

# Step 5: Update kubeconfig
echo -e "\n${YELLOW}Step 5: Configuring kubectl...${NC}"
aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${REGION}
echo -e "${GREEN}✓ kubectl configured${NC}"

# Step 6: Wait for nodes to be ready
echo -e "\n${YELLOW}Step 6: Waiting for EKS nodes to be ready...${NC}"
for i in {1..30}; do
  READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready" || echo "0")
  if [ "$READY_NODES" -ge 2 ]; then
    echo -e "${GREEN}✓ ${READY_NODES} nodes ready${NC}"
    break
  fi
  echo "  Waiting for nodes... (${i}/30)"
  sleep 10
done

# Step 7: Update and apply Kubernetes manifests
echo -e "\n${YELLOW}Step 7: Deploying Kubernetes manifests...${NC}"
cd ../../k8s-manifests

# Update serviceaccount with pod role ARN
sed -i.bak "s|eks.amazonaws.com/role-arn:.*|eks.amazonaws.com/role-arn: ${POD_ROLE_ARN}|" serviceaccount.yaml

# Update deployment with ECR image and environment variables
sed -i.bak "s|image:.*|image: ${ECR_REPO}:latest|" deployment.yaml
sed -i.bak "s|value: \".*\" # CLAIMS_TABLE_NAME|value: \"${CLAIMS_TABLE}\" # CLAIMS_TABLE_NAME|" deployment.yaml
sed -i.bak "s|value: \".*\" # NOTES_BUCKET|value: \"${NOTES_BUCKET}\" # NOTES_BUCKET|" deployment.yaml

kubectl apply -f serviceaccount.yaml
kubectl apply -f deployment.yaml
kubectl apply -f ingress.yaml
echo -e "${GREEN}✓ Application manifests deployed${NC}"

# Step 8: Install AWS Load Balancer Controller via Helm
echo -e "\n${YELLOW}Step 8: Installing AWS Load Balancer Controller...${NC}"
helm repo add eks https://aws.github.io/eks-charts 2>/dev/null || true
helm repo update

# Create service account with IAM role annotation
kubectl create serviceaccount aws-load-balancer-controller -n kube-system --dry-run=client -o yaml | kubectl apply -f -
kubectl annotate serviceaccount aws-load-balancer-controller -n kube-system \
  eks.amazonaws.com/role-arn=$(cd ../iac/terraform && terraform output -raw aws_load_balancer_controller_role_arn) --overwrite

# Install via Helm
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=${CLUSTER_NAME} \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --wait

echo -e "${GREEN}✓ AWS Load Balancer Controller installed${NC}"

# Step 9: Wait for Load Balancer Controller
echo -e "\n${YELLOW}Step 9: Waiting for AWS Load Balancer Controller...${NC}"
for i in {1..60}; do
  LBC_READY=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller \
    --no-headers 2>/dev/null | grep -c "1/1.*Running" || echo "0")
  if [ "$LBC_READY" -ge 1 ]; then
    echo -e "${GREEN}✓ Load Balancer Controller is running${NC}"
    break
  fi
  echo "  Waiting for controller... (${i}/60)"
  sleep 5
done

# Step 10: Wait for ALB to be provisioned
echo -e "\n${YELLOW}Step 10: Waiting for Application Load Balancer...${NC}"
ALB_DNS=""
for i in {1..60}; do
  ALB_DNS=$(kubectl get ingress claim-status-api -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
  if [ -n "$ALB_DNS" ]; then
    echo -e "${GREEN}✓ ALB DNS: ${ALB_DNS}${NC}"
    break
  fi
  echo "  Waiting for ALB... (${i}/60)"
  sleep 10
done

if [ -z "$ALB_DNS" ]; then
  echo -e "${YELLOW}⚠ ALB not ready yet. You can check later with: kubectl get ingress claim-status-api${NC}"
  echo -e "${YELLOW}When ready, update terraform.tfvars with ingress_alb_dns and run: terraform apply${NC}"
else
  # Step 10: Update terraform.tfvars with ALB DNS and re-apply
  echo -e "\n${YELLOW}Step 10: Updating API Gateway integration...${NC}"
  cd ../iac/terraform
  
  # Update ingress_alb_dns in terraform.tfvars
  sed -i.bak "s|ingress_alb_dns.*=.*|ingress_alb_dns        = \"${ALB_DNS}\"|" terraform.tfvars
  
  terraform apply -auto-approve
  echo -e "${GREEN}✓ API Gateway integration configured${NC}"
fi

# Final outputs
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"

API_GATEWAY_ENDPOINT=$(terraform output -raw apigw_endpoint)
CLOUDWATCH_DASHBOARD=$(terraform output -raw cloudwatch_dashboard_url)
echo -e "\n${GREEN}Access your API:${NC}"
if [ -n "$ALB_DNS" ]; then
  echo -e "  API Gateway: ${API_GATEWAY_ENDPOINT}/claims/CLM-1001"
  echo -e "  Direct ALB: http://${ALB_DNS}/claims/CLM-1001"
fi
echo -e "  Port-forward: kubectl port-forward svc/claim-status-api 8080:80"

echo -e "\n${GREEN}Observability:${NC}"
echo -e "  CloudWatch Dashboard: ${CLOUDWATCH_DASHBOARD}"
echo -e "  Container Insights: https://console.aws.amazon.com/cloudwatch/home?region=${REGION}#container-insights:infrastructure/map/${CLUSTER_NAME}"
echo -e "  Application Logs: https://console.aws.amazon.com/cloudwatch/home?region=${REGION}#logsV2:log-groups/log-group/\$252Faws\$252Fcontainerinsights\$252F${CLUSTER_NAME}\$252Fapplication"
echo -e "  Performance Metrics: https://console.aws.amazon.com/cloudwatch/home?region=${REGION}#logsV2:log-groups/log-group/\$252Faws\$252Fcontainerinsights\$252F${CLUSTER_NAME}\$252Fperformance"

echo -e "\n${GREEN}Test commands:${NC}"
if [ -n "$ALB_DNS" ]; then
  echo -e "  curl ${API_GATEWAY_ENDPOINT}/claims/CLM-1001"
  echo -e "  curl -X POST ${API_GATEWAY_ENDPOINT}/claims/CLM-1001/summarize"
fi

echo -e "\n${GREEN}Useful commands:${NC}"
echo -e "  kubectl get pods -A"
echo -e "  kubectl logs -l app=claim-status-api"
echo -e "  kubectl get ingress claim-status-api"
echo -e "  aws logs tail /aws/containerinsights/${CLUSTER_NAME}/application --follow"
echo -e "  terraform output"

cd ../..
