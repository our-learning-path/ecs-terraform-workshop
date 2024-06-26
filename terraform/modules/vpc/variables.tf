variable "vpc" {
  type = object({
    name                 = string
    cidr_block           = string
    azs                  = list(string)
    private_subnets      = list(string)
    public_subnets       = list(string)
    enable_ipv6          = bool
    enable_nat_gateway   = bool
    enable_vpn_gateway   = bool
    enable_dns_hostnames = bool
    enable_dns_support   = bool
  })
  default = {
    name                 = "ecs-vpc"
    cidr_block           = "10.0.0.0/16"
    azs                  = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
    private_subnets      = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
    public_subnets       = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
    enable_ipv6          = false
    enable_nat_gateway   = false
    enable_vpn_gateway   = false
    enable_dns_hostnames = true
    enable_dns_support   = true
  }
}

variable "tags" {
  type = map(any)
  default = {
    Environment = "dev"
    Component   = "vpc"
  }
}
