terraform {
  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 5.0" }
    tls        = { source = "hashicorp/tls", version = "~> 4.0" }
    local      = { source = "hashicorp/local", version = "~> 2.0" }
    cloudflare = { source = "cloudflare/cloudflare", version = "~> 3.0" }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

resource "tls_private_key" "k8s_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "k8s_key_pair" {
  key_name   = "${var.cluster_name}-key"
  public_key = tls_private_key.k8s_key.public_key_openssh
}

resource "local_file" "private_key" {
  content         = tls_private_key.k8s_key.private_key_pem
  filename        = "${path.module}/../ansible/${var.cluster_name}.pem"
  file_permission = "0400" # chỉ owner đọc được, SSH yêu cầu permission này
}

resource "null_resource" "run_ansible" {
  # Ý nghĩa: Chỉ chạy block này sau khi các máy Master và Worker đã được tạo xong hoàn toàn
  depends_on = [
    aws_instance.master,
    aws_instance.worker1,
    aws_instance.worker2,
    local_file.ansible_inventory
  ]
  # 3. Kích hoạt lệnh chạy Ansible Playbook tự động
  provisioner "local-exec" {
    command = <<EOT
      cd ${path.module}/../ansible
      ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.ini playbook.yml
    EOT
  }
}
