variable "vpc_name" {
  description = "Название VPC"  
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR публичной подсети"
  type        = string
}

variable "private_subnet_cidr" {
  description = "CIDR приватной подсети"
  type        = string
}

variable "zone" {
  description = "Зона"
  type        = string
} 