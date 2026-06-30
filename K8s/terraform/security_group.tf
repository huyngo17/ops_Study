// sercurity group
locals {
  public_ports = {
    "ssh"            = 22
    "kube-apiserver" = 6443
    "http"           = 80
    "https"          = 443
  }
}

resource "aws_security_group" "sg" {
  name   = "${var.cluster_name}-sg"
  vpc_id = aws_vpc.vpc.id

  dynamic "ingress" {
    for_each = local.public_ports
    content {
      description = "Allow ${ingress.key}"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  ingress {
    description = "Kubernetes NodePort Services"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow all traffic between nodes in this SG"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }
  egress {
    description = "Allow all outbound traffic (Pull image, apt update, AWS API)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

