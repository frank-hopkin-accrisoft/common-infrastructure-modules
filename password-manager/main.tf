data "aws_caller_identity" "current" {}

data "aws_acm_certificate" "wildcard_cert" {
  domain = "*.${var.company_domain}"
}

# lookup server AMI
data "aws_ami" "ami" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

#lookup route53 hosted zone for domain
data "aws_route53_zone" "vpn_hosted_zone" {
  name = var.company_domain
}

#lookup default ebs kms key
data "aws_kms_key" "aws_managed_ebs_key" {
  key_id = "alias/aws/ebs"
}

# Generates a secure private key and encodes it as PEM
resource "tls_private_key" "key_pair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create the Key Pair
resource "aws_key_pair" "key_pair" {
  key_name   = "vaultwarden_server_key_pair"
  public_key = tls_private_key.key_pair.public_key_openssh
}

# Save file
resource "local_file" "ssh_key" {
  filename = "${aws_key_pair.key_pair.key_name}.pem"
  content  = tls_private_key.key_pair.private_key_pem
}

# Created EC2
resource "aws_instance" "vaultwarden_server" {
  depends_on = [
    aws_key_pair.key_pair
  ]
  ami           = data.aws_ami.ami.id
  instance_type = "t2.medium"

  key_name               = "vaultwarden_server_key_pair"
  vpc_security_group_ids = var.server_security_groups
  subnet_id              = var.server_subnets

  root_block_device {
    volume_size           = 30
    encrypted             = true
    kms_key_id            = data.aws_kms_key.aws_managed_ebs_key.arn
    delete_on_termination = false
  }

  user_data = file("${path.module}/scripts/setup_vaultwarden.sh")
  tags      = merge({
    Name = "Vaultwarden Server",
    snapshot = "True"
  }, var.tags)

  lifecycle {
    ignore_changes = [ami]
  }
}

#Create load balancer
resource "aws_lb" "alb" {
  depends_on                       = [aws_instance.vaultwarden_server]
  name                             = "vaultwarden-lb"
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


#Create load balancer target group
resource "aws_alb_target_group" "alb_tg" {
  depends_on  = [aws_lb.alb]
  name        = "vaultwarden-tg"
  vpc_id      = var.vpc_id
  protocol    = "HTTP"
  target_type = "instance"
  port        = var.port

  health_check {
    path = "/"
  }
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

#Create HTTP listener that auto redirects to HTTPS
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

#Create HTTPS listener
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

#Attach target group to ec2 instance
resource "aws_alb_target_group_attachment" "tg_to_vaultwarden_server" {
  target_group_arn = aws_alb_target_group.alb_tg.arn
  target_id        = aws_instance.vaultwarden_server.id
}

#Create CName record for LB DNS
resource "aws_route53_record" "vaultwarden" {
  depends_on = [aws_instance.vaultwarden_server]
  zone_id    = data.aws_route53_zone.vpn_hosted_zone.zone_id
  name       = "vault.${data.aws_route53_zone.vpn_hosted_zone.name}"
  type       = "CNAME"
  ttl        = "300"
  records    = [aws_lb.alb.dns_name]
}