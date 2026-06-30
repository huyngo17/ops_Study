variable "aws_region" {
  default = "ap-southeast-1"
}

//biến cho vpc 
variable "vpc_cidr" { default = "10.0.0.0/16" }
variable "cluster_name" { default = "k8s-study" }

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
