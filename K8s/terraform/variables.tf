variable "aws_region" {
  default = "ap-southeast-1"
}

variable "aws_id" {
  default = "057817979917"
}

//biến cho vpc 
variable "vpc_cidr" { default = "10.0.0.0/16" }
variable "cluster_name" { default = "k8s-study" }

variable "domain_suffix" {
  type    = string
  default = "ops-study.xyz"
}

variable "dns_name" {
  type        = string
  default     = "*.ops-study.xyz"
  description = "Wildcard DNS name để tạo CNAME record trên Cloudflare"
}

variable "cloudflare_zone_id" {
  type        = string
  description = "Zone ID của domain trên Cloudflare"
}

variable "cloudflare_api_token" {
  type        = string
  description = "API token Cloudflare có quyền sửa DNS records"
  sensitive   = true
}

//biến cho subnet
variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "control_plane_instance_type" {
  default = "c7i-flex.large"
}

variable "worker_instance_type" {
  default = "m7i-flex.large"
}

variable "aws_acm_certificate_arn" {
  type        = string
  description = "ARN của chứng chỉ SSL/TLS từ AWS ACM"
}
