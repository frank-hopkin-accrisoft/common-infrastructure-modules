provider "aws" {
  region = "us-east-1"
}

module "vpn" {
  source                     = "./vpn"
  company_domain             = "tigrisconsulting.cloud"
  vpn_server_security_groups = ["sg-e684ecec"]
  vpn_server_subnets         = "subnet-82b017b3"
  tags                       = {
    Name = "vpn test"
  }
}

module "bitwarden" {
  source                 = "./password-manager"
  company_domain         = "tigrisconsulting.cloud"
  vpc_id                 = "vpc-1771dd6a"
  server_security_groups = ["sg-e684ecec"]
  server_subnets         = "subnet-82b017b3"
  lb_security_groups     = ["sg-e684ecec"]
  lb_subnets             = ["subnet-82b017b3", "subnet-02940a23"]
  port                   = 80
  tags                   = {
    Name = "vaultwarden resource"
  }
}