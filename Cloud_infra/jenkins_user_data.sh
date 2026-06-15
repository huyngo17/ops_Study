#!/bin/bash
set -e

# 1. Cài đặt các gói cần thiết trên Host (EC2)
apt update
apt upgrade -y
apt install -y docker.io unzip curl

# 2. Cấu hình Docker trên Host
systemctl enable --now docker
usermod -aG docker ubuntu
chmod 666 /var/run/docker.sock

# 3. Tạo volume cho Jenkins
docker volume create jenkins_home

# 4. Chạy Jenkins Container với bản JDK 17 mới, tối ưu hóa công cụ
docker run -d --name jenkins \
  --restart unless-stopped \
  -u root \
  -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /usr/bin/docker:/usr/bin/docker \
  -e AWS_DEFAULT_REGION=ap-southeast-1 \
  jenkins/jenkins:lts-jdk17

# 5. Đợi Jenkins lên và cài đặt AWS CLI trực tiếp bên trong container để tránh lỗi thư viện shared
echo "Waiting for Jenkins to initialize..."
until docker exec jenkins test -f /var/jenkins_home/secrets/initialAdminPassword
do
  sleep 5
done

# Cài đặt awscli trực tiếp vào container Jenkins
docker exec jenkins apt-get update
docker exec jenkins apt-get install -y awscli

# 6. Đẩy mật khẩu lên AWS SSM Parameter Store
JENKINS_PASSWORD=$(docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword)

aws ssm put-parameter \
  --name "/jenkins/initial_admin_password" \
  --value "$JENKINS_PASSWORD" \
  --type "SecureString" \
  --overwrite \
  --region ap-southeast-1