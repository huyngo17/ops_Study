resource "aws_lb" "k8s_alb" {
  name               = "${var.cluster_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg.id]
  subnets            = [aws_subnet.public_sub_1.id, aws_subnet.public_sub_2.id]

  tags = {
    Name = "${var.cluster_name}-alb"
  }
}

# --- TARGET GROUPS ---

# Target Group cho HTTP (Port 30080) - ALB terminate TLS và forward HTTP tới Ingress NGINX
resource "aws_lb_target_group" "k8s_tg_http" {
  name        = "${var.cluster_name}-tg-http"
  port        = 30080
  protocol    = "HTTP"
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

# --- LISTENERS ---

# Listener HTTP (Port 80) - redirect lên HTTPS
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.k8s_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      protocol    = "HTTPS"
      port        = "443"
      status_code = "HTTP_301"
    }
  }
}

# Listener HTTPS (Port 443) - terminate TLS với ACM
resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.k8s_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = var.aws_acm_certificate_arn
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.k8s_tg_http.arn
  }
}

# --- ATTACHMENTS ---

resource "aws_lb_target_group_attachment" "attach_worker1_http" {
  target_group_arn = aws_lb_target_group.k8s_tg_http.arn
  target_id        = aws_instance.worker1.id
  port             = 30080
}

resource "aws_lb_target_group_attachment" "attach_worker2_http" {
  target_group_arn = aws_lb_target_group.k8s_tg_http.arn
  target_id        = aws_instance.worker2.id
  port             = 30080
}

resource "cloudflare_record" "wildcard_cname" {
  zone_id         = var.cloudflare_zone_id
  name            = replace(var.dns_name, ".${var.domain_suffix}", "")
  type            = "CNAME"
  value           = aws_lb.k8s_alb.dns_name
  ttl             = 1
  proxied         = false
  allow_overwrite = true
}

output "alb_dns_name" {
  description = "Domain Name System (DNS) của Application Load Balancer để cấu hình bản ghi CNAME"
  value       = aws_lb.k8s_alb.dns_name
}
