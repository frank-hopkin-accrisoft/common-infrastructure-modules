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

variable "security_groups" {
  default = ""
}

variable "subnets" {
  default = ""
}

variable "comany_domain" {
  type = string
}