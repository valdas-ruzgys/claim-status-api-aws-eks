terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

locals {
  name   = var.name
  tags   = merge(var.tags, { "project" = local.name })
  vpc_cidr = "10.20.0.0/16"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.13"

  name = local.name
  cidr = local.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = [for i in range(3) : cidrsubnet(local.vpc_cidr, 4, i)]
  public_subnets  = [for i in range(3) : cidrsubnet(local.vpc_cidr, 4, i + 3)]
  enable_nat_gateway = true
  single_nat_gateway = true
  tags = local.tags
}

data "aws_availability_zones" "available" {}

resource "aws_ecr_repository" "claims" {
  name                 = "${local.name}-api"
  image_scanning_configuration { scan_on_push = true }
  force_delete         = true
  tags = local.tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name    = "${local.name}-eks"
  cluster_version = "1.31"
  subnet_ids      = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id
  enable_irsa     = true

  # Enable public endpoint access for kubectl
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # Disable KMS encryption to avoid permission issues
  create_kms_key = false
  cluster_encryption_config = {}

  # Grant current IAM user admin access to the cluster
  enable_cluster_creator_admin_permissions = true

  # Enable CloudWatch logging for control plane
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Container Insights add-on configuration
  cluster_addons = {
    amazon-cloudwatch-observability = {
      most_recent = true
    }
  }

  eks_managed_node_groups = {
    default = {
      instance_types = [var.worker_instance_type]
      desired_size   = 2
      max_size       = 4
      min_size       = 2
      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
        CloudWatchAgentServerPolicy  = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
      }
    }
  }

  tags = local.tags
}

# AWS Load Balancer Controller IAM Role
module "aws_load_balancer_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                              = "${local.name}-aws-load-balancer-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = local.tags
}

output "aws_load_balancer_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = module.aws_load_balancer_controller_irsa.iam_role_arn
}

resource "aws_dynamodb_table" "claims" {
  name         = "${local.name}-claims"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  attribute {
    name = "id"
    type = "S"
  }
  tags = local.tags
}

resource "aws_s3_bucket" "notes" {
  bucket = "${local.name}-claim-notes"
  tags   = local.tags
}

resource "aws_s3_bucket_versioning" "notes" {
  bucket = aws_s3_bucket.notes.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_iam_role" "bedrock" {
  name = "${local.name}-bedrock-role"
  assume_role_policy = data.aws_iam_policy_document.bedrock_assume.json
  tags = local.tags
}

data "aws_iam_policy_document" "bedrock_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com", "ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy" "bedrock_access" {
  name = "${local.name}-bedrock-policy"
  role = aws_iam_role.bedrock.id
  policy = data.aws_iam_policy_document.bedrock_access.json
}

data "aws_iam_policy_document" "bedrock_access" {
  statement {
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:BatchGetItem",
      "s3:GetObject"
    ]
    resources = [
      aws_dynamodb_table.claims.arn,
      "${aws_dynamodb_table.claims.arn}/index/*",
      "${aws_s3_bucket.notes.arn}/*"
    ]
  }
}

resource "aws_apigatewayv2_api" "http" {
  name          = "${local.name}-api"
  protocol_type = "HTTP"
  tags          = local.tags
}

resource "aws_apigatewayv2_integration" "eks" {
  count                  = var.ingress_alb_dns != "" ? 1 : 0
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "HTTP_PROXY"
  integration_uri        = "http://${var.ingress_alb_dns}"
  integration_method     = "ANY"
  payload_format_version = "1.0"
}

resource "aws_apigatewayv2_route" "claims" {
  count     = var.ingress_alb_dns != "" ? 1 : 0
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.eks[0].id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true
  tags        = local.tags
}

output "cluster_name" { value = module.eks.cluster_name }
output "repository_url" { value = aws_ecr_repository.claims.repository_url }
output "claims_table" { value = aws_dynamodb_table.claims.name }
output "notes_bucket" { value = aws_s3_bucket.notes.bucket }
output "apigw_endpoint" { value = aws_apigatewayv2_api.http.api_endpoint }
