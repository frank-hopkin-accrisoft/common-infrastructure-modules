variable "vpn_cidr" {
  default = "0.0.0.0/32"
}
variable "project" {
  type        = string
  description = "The name of the project"
}

variable "environment" {
  description = "The deployment environment"
}

variable "region" {
  description = "The AWS Region"
}

variable "vpc_cidr" {
  description = "The CIDR block of the vpc"
}

variable "public_subnets_cidr" {
  type        = list(object({cidr=string, name=string, az=string}))
  description = "The CIDR block for the public subnet"
}

variable "private_subnets_cidr" {
  type        = list(object({cidr=string, name=string, az=string}))
  description = "The CIDR block for the private subnet"
}
variable "account_id" {
  type        = string
  description = "The AWS Account Id"
}

variable "tags" {
  type = map(any)
}

variable "flow_log_cloudwatch_group" {
  type = string
}