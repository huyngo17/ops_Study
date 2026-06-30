data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "master" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.control_plane_instance_type
  subnet_id                   = aws_subnet.public_sub_1.id
  associate_public_ip_address = true
  key_name                    = aws_key_pair.k8s_key_pair.key_name
  vpc_security_group_ids      = [aws_security_group.sg.id]
  iam_instance_profile        = aws_iam_instance_profile.k8s_node_profile.name
  source_dest_check           = false
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
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.worker_instance_type
  subnet_id                   = aws_subnet.public_sub_1.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.sg.id]
  iam_instance_profile        = aws_iam_instance_profile.k8s_node_profile.name
  key_name                    = aws_key_pair.k8s_key_pair.key_name
  source_dest_check           = false
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
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.worker_instance_type
  subnet_id                   = aws_subnet.public_sub_1.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.sg.id]
  iam_instance_profile        = aws_iam_instance_profile.k8s_node_profile.name
  key_name                    = aws_key_pair.k8s_key_pair.key_name
  source_dest_check           = false
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