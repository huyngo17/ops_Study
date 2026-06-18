terraform {
  required_providers {
     aws   = { source = "hashicorp/aws",       version = "~> 5.0" }
     tls   = { source = "hashicorp/tls",       version = "~> 4.0" }
     local = { source = "hashicorp/local",     version = "~> 2.0" }
  }
}
provider "aws" {
  region =  var.aws_region
}

//start resource
resource "aws_vpc" "vpc" {
    cidr_block = var.vpc_cidr
    enable_dns_hostnames = true
    tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.vpc.id
}

//public subnet
resource "aws_subnet" "public_sub_1" {
    vpc_id = aws_vpc.vpc.id
    cidr_block = var.public_subnet_cidrs[0]
    availability_zone =  "${var.aws_region}a"
    map_public_ip_on_launch = true
    tags = {
        "kubernetes.io/cluster/${var.cluster_name}" = "owned"
        "kubernetes.io/role/elb" = "1"
    }
}

resource "aws_route_table" "route_table" {
    vpc_id = aws_vpc.vpc.id
    route {
        cidr_block = "0.0.0.0/0" 
        gateway_id = aws_internet_gateway.igw.id
    }
}

resource "aws_route_table_association" "association" {
    route_table_id = aws_route_table.route_table.id
    subnet_id = aws_subnet.public_sub_1.id

}

//private subnet
resource "aws_subnet" "private_sub_1" {
    vpc_id = aws_vpc.vpc.id
    cidr_block = var.private_subnet_cidrs[0]
    availability_zone =  "${var.aws_region}a"
    tags = {
        "kubernetes.io/cluster/${var.cluster_name}" = "owned"
        "kubernetes.io/role/internal-elb" = "1"
    }
}

resource "aws_route_table" "route_table_private" {
    vpc_id = aws_vpc.vpc.id
}

resource "aws_route_table_association" "association_private" {
    route_table_id = aws_route_table.route_table_private.id
    subnet_id = aws_subnet.private_sub_1.id
}



// sercurity group
locals {
  public_ports = {
    "ssh"          = 22
    "kube-apiserver" = 6443
    "http"         = 80
    "https"        = 443
  }
}

resource "aws_security_group" "sg" {
    name = "${var.cluster_name}-sg"
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



resource "aws_iam_role" "k8s_node_role" {
   name = "${var.cluster_name}-node-role"
   assume_role_policy = jsonencode({
        "Version" = "2012-10-17"
        "Statement": [
            {
                "Action": "sts:AssumeRole",
                "Effect": "Allow",
                "Principal": {
                    "Service": "ec2.amazonaws.com"
                }
            }
        ]
   })
}

resource "aws_iam_role_policy_attachment" "k8s_node_ecr_readonly" {
    role       = aws_iam_role.k8s_node_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "k8s_node_profile" {
    name = "${var.cluster_name}-node-profile"
    role = aws_iam_role.k8s_node_role.name
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] 

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "master" {
    ami = data.aws_ami.ubuntu.id
    instance_type = var.control_plane_instance_type
    subnet_id = aws_subnet.public_sub_1.id
    associate_public_ip_address = true
    key_name = aws_key_pair.k8s_key_pair.key_name
    vpc_security_group_ids = [aws_security_group.sg.id]
    iam_instance_profile = aws_iam_instance_profile.k8s_node_profile.name
    source_dest_check = false
    root_block_device {
        volume_size           = 20 # Free Tier cho phép tối đa 30GB tổng cộng
        volume_type           = "gp3"
        delete_on_termination = true
    }
    tags = {
        Name                                        = "${var.cluster_name}-master"
        "kubernetes.io/cluster/${var.cluster_name}" = "owned" 
    }
}

resource "aws_instance" "worker1" {
    ami = data.aws_ami.ubuntu.id
    instance_type = var.worker_instance_type

    # [OPTION A - ĐANG DÙNG] Public subnet: worker có public IP, ra internet thẳng qua IGW
    # Dùng khi: học, dev, tiết kiệm chi phí
    # Rủi ro: node exposed internet, nhưng Security Group đã giới hạn port vào
    subnet_id = aws_subnet.public_sub_1.id
    associate_public_ip_address = true

    # [OPTION B - PRODUCTION] Private subnet + NAT Gateway + Elastic IP
    # Lý do nên dùng khi production:
    #   - Worker không có public IP → không ai từ internet SSH hay scan được
    #   - Vẫn ra internet được qua NAT để pull image, apt update, gọi AWS API
    #   - Elastic IP gắn vào NAT Gateway giúp outbound traffic có IP cố định
    #     → dùng để whitelist IP ở bên thứ 3 (Docker Hub rate limit, private registry...)
    #   - Nếu bị tấn công DDoS vào public IP của master, worker vẫn không bị ảnh hưởng
    # Để bật: đổi subnet_id = aws_subnet.private_sub_1.id
    #          set associate_public_ip_address = false
    #          tạo thêm: aws_eip + aws_nat_gateway + route trong route_table_private

    vpc_security_group_ids = [ aws_security_group.sg.id ]
    iam_instance_profile = aws_iam_instance_profile.k8s_node_profile.name
    key_name = aws_key_pair.k8s_key_pair.key_name
    source_dest_check = false
     root_block_device {
        volume_size           = 20
        volume_type           = "gp3"
        delete_on_termination = true
    }
    tags = {
        Name                                        = "${var.cluster_name}-worker-1"
        "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
}

resource "aws_instance" "worker2" {
    ami = data.aws_ami.ubuntu.id
    instance_type = var.worker_instance_type

    # [OPTION A - ĐANG DÙNG] Public subnet: worker có public IP, ra internet thẳng qua IGW
    # Dùng khi: học, dev, tiết kiệm chi phí
    # Rủi ro: node exposed internet, nhưng Security Group đã giới hạn port vào
    subnet_id = aws_subnet.public_sub_1.id
    associate_public_ip_address = true

    # [OPTION B - PRODUCTION] Private subnet + NAT Gateway + Elastic IP
    # Lý do nên dùng khi production:
    #   - Worker không có public IP → không ai từ internet SSH hay scan được
    #   - Vẫn ra internet được qua NAT để pull image, apt update, gọi AWS API
    #   - Elastic IP gắn vào NAT Gateway giúp outbound traffic có IP cố định
    #     → dùng để whitelist IP ở bên thứ 3 (Docker Hub rate limit, private registry...)
    #   - Nếu bị tấn công DDoS vào public IP của master, worker vẫn không bị ảnh hưởng
    # Để bật: đổi subnet_id = aws_subnet.private_sub_1.id
    #          set associate_public_ip_address = false
    #          tạo thêm: aws_eip + aws_nat_gateway + route trong route_table_private

    vpc_security_group_ids = [ aws_security_group.sg.id ]
    iam_instance_profile = aws_iam_instance_profile.k8s_node_profile.name
    key_name = aws_key_pair.k8s_key_pair.key_name
    source_dest_check = false
     root_block_device {
        volume_size           = 20 # Free Tier cho phép tối đa 30GB tổng cộng
        volume_type           = "gp3"
        delete_on_termination = true
    }
    tags = {
        Name                                        = "${var.cluster_name}-worker-2"
        "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
}

# Tạo key pair

resource "tls_private_key" "k8s_key" {
    algorithm = "RSA"
    rsa_bits = 4096
}

resource "aws_key_pair" "k8s_key_pair" {
    key_name   = "${var.cluster_name}-key"
    public_key = tls_private_key.k8s_key.public_key_openssh
}

resource "local_file" "private_key" {
  content         = tls_private_key.k8s_key.private_key_pem
  filename        = "${path.module}/${var.cluster_name}.pem"
  file_permission = "0400"  # chỉ owner đọc được, SSH yêu cầu permission này
}