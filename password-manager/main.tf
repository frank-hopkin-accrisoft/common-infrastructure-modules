data "aws_caller_identity" "current" {}

data "aws_acm_certificate" "wildcard_cert" {
  domain = "*.${var.comany_domain}"
}

resource "aws_ecr_repository" "bitwarden" {
  name = "bitwarden-server"
}

resource "aws_ecs_cluster" "bitwarden" {
  name = "bitwarden"
}

resource "aws_ecs_service" "bitwarden" {
  name          = "bitwarden"
  cluster       = aws_ecs_cluster.bitwarden.name
  desired_count = 1
  launch_type   = "FARGATE"

  deployment_controller {
    type = "ECS"
  }

  network_configuration {
    subnets          = var.subnets
    security_groups  = var.security_groups
    assign_public_ip = false
  }

  health_check_grace_period_seconds = 300

  load_balancer {
    target_group_arn = aws_alb_target_group.alb_tg.arn
    container_name   = "bitwarden-server"
    container_port   = "8080"
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  task_definition = jsonencode({})

  tags = var.tags
}

resource "aws_lb" "alb" {
  name                             = "bitwarden_lb"
  internal                         = false
  load_balancer_type               = "application"
  enable_deletion_protection       = true
  subnets                          = var.lb_subnets
  security_groups                  = var.lb_security_groups
  enable_cross_zone_load_balancing = true

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

resource "aws_alb_target_group" "alb_tg" {
  depends_on  = [aws_lb.alb]
  name        = "bitwarden-tg"
  vpc_id      = var.vpc_id
  protocol    = "HTTP"
  target_type = "ip"
  port        = var.port

  #  health_check {
  #    path = var.health_check_path
  #  }
  lifecycle {
    create_before_destroy = true
  }
  stickiness {
    enabled = false
    type    = "lb_cookie"
    //https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group#stickiness
  }

  tags = var.tags
}

resource "aws_lb_listener" "alb_listener_http" {
  depends_on = [
    aws_lb.alb,
    aws_alb_target_group.alb_tg
  ]
  load_balancer_arn = aws_lb.alb.id
  port              = var.port
  protocol          = "HTTP"

  lifecycle {
    create_before_destroy = true
  }

  default_action {
    type = "redirect"
    redirect {
      port        = 443
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = var.tags
}

resource "aws_lb_listener" "alb_listener_https" {
  depends_on = [
    aws_lb.alb,
    aws_alb_target_group.alb_tg
  ]
  load_balancer_arn = aws_lb.alb.id
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = data.aws_acm_certificate.wildcard_cert.arn
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-Ext-2018-06"
  default_action {
    target_group_arn = aws_alb_target_group.alb_tg.id
    type             = "forward"
  }
  lifecycle {
    create_before_destroy = true
  }
  tags = var.tags
}