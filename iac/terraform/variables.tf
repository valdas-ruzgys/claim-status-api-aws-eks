variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Base name/prefix for resources"
  type        = string
  default     = "claim-status"
}

variable "worker_instance_type" {
  description = "EKS managed node instance type"
  type        = string
  default     = "m6i.large"
}

variable "tags" {
  description = "Default resource tags"
  type        = map(string)
  default     = {}
}

variable "ingress_alb_dns" {
  description = "ALB DNS that fronts the Kubernetes ingress (set after deploying ingress controller)"
  type        = string
  default     = ""
}

variable "github_connection_arn" {
  description = "CodeStar connection ARN for GitHub"
  type        = string
}

variable "github_owner" {
  description = "GitHub organization/user name"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "repo_branch" {
  description = "Git branch to build"
  type        = string
  default     = "main"
}
