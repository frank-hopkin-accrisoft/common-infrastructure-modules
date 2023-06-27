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