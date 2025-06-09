variable "default_zone" {
  description = "Зона по умолчанию"
  type        = string
  default     = "ru-central1-a"
}

variable "vpc_name" {
  description = "Имя VPC"
  type        = string
  default     = "main-vpc"
}

variable "public_subnet_cidr" {
  description = "CIDR блок для публичной подсети"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR блок для приватной подсети"
  type        = string
  default     = "10.0.2.0/24"
}

variable "db_name" {
  description = "Имя базы данных PostgreSQL"
  type        = string
  default     = "main_db"
}

variable "db_user" {
  description = "Пользователь базы данных"
  type        = string
  default     = "db_user"
}

variable "db_password" {
  description = "Пароль базы данных"
  type        = string
  sensitive   = true
}

variable "enable_postgres" {
  description = "Включить развертывание PostgreSQL кластера"
  type        = bool
  default     = true
}

variable "ssh_access_rules" {
  description = "Правила доступа по SSH"
  type = map(object({
    ip_address  = string
    description = string
  }))
  default = {
    "my_home" = {
      ip_address  = "0.0.0.0/0"
      description = "Home IP access"
    }
  }
}

variable "servers_config" {
  description = "Конфигурация серверов"
  type = map(object({
    is_public = bool
    cores     = number
    memory    = number
    disk_size = number
    image_id  = string
    sg_config = object({
      ingress_rules = list(object({
        protocol       = string
        port_range     = object({
          from = number
          to   = number
        })
        predefined_target = optional(string)
        cidr_blocks      = optional(list(string))
        description      = string
      }))
      egress_rules = list(object({
        protocol       = string
        port_range     = object({
          from = number
          to   = number
        })
        predefined_target = optional(string)
        cidr_blocks      = optional(list(string))
        description      = string
      }))
    })
  }))
  
  default = {
    "bastion" = {
      is_public = true
      cores     = 2
      memory    = 2
      disk_size = 10
      image_id  = "fd8kdq6d0p8sij7h5qe3"
      sg_config = {
        ingress_rules = [
          {
            protocol = "TCP"
            port_range = {
              from = 22
              to   = 22
            }
            cidr_blocks = ["0.0.0.0/0"]
            description = "SSH access"
          }
        ]
        egress_rules = [
          {
            protocol = "ANY"
            port_range = {
              from = 0
              to   = 65535
            }
            predefined_target = "internet"
            description = "All outbound traffic"
          }
        ]
      }
    }
    "private_server" = {
      is_public = false
      cores     = 2
      memory    = 2
      disk_size = 10
      image_id  = "fd8kdq6d0p8sij7h5qe3"
      sg_config = {
        ingress_rules = [
          {
            protocol = "TCP"
            port_range = {
              from = 22
              to   = 22
            }
            cidr_blocks = ["10.0.1.0/24"]
            description = "SSH from bastion"
          }
        ]
        egress_rules = [
          {
            protocol = "ANY"
            port_range = {
              from = 0
              to   = 65535
            }
            predefined_target = "internet"
            description = "All outbound traffic"
          }
        ]
      }
    }
  }
} 