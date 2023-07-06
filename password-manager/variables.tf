variable "lb_subnets" {
  type = list(string)
}

variable "lb_security_groups" {
  type = list(string)
}

variable "tags" {
  type = map(any)
}

variable "port" {
  type        = number
  description = "port application runs on"
}

variable "vpc_id" {
  type = string
}

variable "server_security_groups" {
  default = ""
}

variable "server_subnets" {
  default = ""
}

variable "company_domain" {
  type = string
}