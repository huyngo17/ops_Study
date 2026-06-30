resource "aws_lb" "k8s_alb" {
  name               = "${var.cluster_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg.id] # Dùng chung SG để mở port 80/443
  subnets            = [aws_subnet.public_sub_1.id, aws_subnet.public_sub_2.id]

  tags = {
    Name = "${var.cluster_name}-alb"
  }
}

# HTTP 
resource "aws_lb_target_group" "k8s_tg_http" {
  name        = "${var.cluster_name}-tg-http"
  port        = 30080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/healthz" # Đường dẫn health check mặc định của Ingress Nginx
    port                = "30080"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Tạo Listener cho ALB hứng port 80 của người dùng và ném vào Target Group
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.k8s_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.k8s_tg_http.arn
  }
}

resource "aws_lb_target_group_attachment" "attach_worker1" {
  target_group_arn = aws_lb_target_group.k8s_tg_http.arn
  target_id        = aws_instance.worker1.id
  port             = 30080
}

resource "aws_lb_target_group_attachment" "attach_worker2" {
  target_group_arn = aws_lb_target_group.k8s_tg_http.arn
  target_id        = aws_instance.worker2.id
  port             = 30080
}

#HTTPS
resource "aws_lb_target_group" "k8s_tg_https" {
  name        = "${var.cluster_name}-tg-https"
  port        = 30443
  protocol    = "HTTPS"
  vpc_id      = aws_vpc.vpc.id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/healthz" 
    port                = "30080"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.k8s_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.aws_acm_certificate_arn # Nên dùng ACM Certificate của AWS để ALB tự lo SSL

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.k8s_tg_https.arn
  }
}

resource "aws_lb_target_group_attachment" "attach_worker1_https" {
  target_group_arn = aws_lb_target_group.k8s_tg_https.arn
  target_id        = aws_instance.worker1.id
  port             = 30443
}

resource "aws_lb_target_group_attachment" "attach_worker2_https" {
  target_group_arn = aws_lb_target_group.k8s_tg_https.arn
  target_id        = aws_instance.worker2.id
  port             = 30443
}

output "alb_dns_name" {
  description = "Domain Name System (DNS) của Application Load Balancer để cấu hình bản ghi CNAME"
  value       = aws_lb.k8s_alb.dns_name
}