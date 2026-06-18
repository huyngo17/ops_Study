output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "master_public_ip" {
  value = aws_instance.master.public_ip
}

output "worker1_public_ip" {
  value = aws_instance.worker1.public_ip
}

output "worker2_public_ip" {
  value = aws_instance.worker2.public_ip
}

# Copy paste thẳng vào ansible/inventory.ini sau khi apply
output "ansible_inventory" {
  value = <<-EOT

    [control_plane]
    master  ansible_host=${aws_instance.master.public_ip}

    [workers]
    worker1 ansible_host=${aws_instance.worker1.public_ip}
    worker2 ansible_host=${aws_instance.worker2.public_ip}

    [k8s_cluster:children]
    control_plane
    workers
  EOT
}
