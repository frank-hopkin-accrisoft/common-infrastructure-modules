# lookup server AMI
data "aws_ami" "vpn_ami" {
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

# Generates a secure private key and encodes it as PEM
resource "tls_private_key" "key_pair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create the Key Pair
resource "aws_key_pair" "key_pair" {
  key_name   = "vpn_server_key_pair"
  public_key = tls_private_key.key_pair.public_key_openssh
}

# Save file
resource "local_file" "ssh_key" {
  filename = "${aws_key_pair.key_pair.key_name}.pem"
  content  = tls_private_key.key_pair.private_key_pem
}

# Created EC2
resource "aws_instance" "vpn_server" {
  depends_on = [
    aws_key_pair.key_pair
  ]
  ami           = data.aws_ami.vpn_ami.id
  instance_type = "t2.micro"

  key_name               = "vpn_server_key_pair"
  vpc_security_group_ids = var.vpn_server_security_groups
  subnet_id              = var.vpn_server_subnets

  root_block_device {
    volume_size = 30
    encrypted = true
  }

  user_data = file("${path.module}/scripts/setup_vpn.sh")
}

# Add A record for vpn.comanydomain.com
resource "aws_route53_record" "vpn" {
  depends_on = [aws_instance.vpn_server]
  zone_id    = data.aws_route53_zone.vpn_hosted_zone.zone_id
  name       = "vpn.${data.aws_route53_zone.vpn_hosted_zone.name}"
  type       = "A"
  ttl        = "300"
  records    = [aws_instance.vpn_server.public_ip]
}