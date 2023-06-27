variable "tags" {
  type        = map(any)
  description = "map of tags you want added to all resources"
}

variable "vpn_server_security_groups" {
  type        = list(string)
  description = "Security group vpn server will run in"
}
variable "vpn_server_subnets" {
  type        = string
  description = "Subnet vpn server will run in"
}

variable "company_domain" {
  type        = string
  description = "Company domain e.g. companyA.com"
}
