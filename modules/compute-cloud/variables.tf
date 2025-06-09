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
}

variable "network_id" {
  description = "ID сети"
  type        = string
}

variable "public_subnet_id" {
  description = "ID публичной подсети"
  type        = string
}

variable "private_subnet_id" {
  description = "ID приватной подсети"
  type        = string
}

variable "zone" {
  description = "Зона"
  type        = string
}

variable "ssh_access_rules" {
  description = "Правила доступа по SSH"
  type = map(object({
    ip_address  = string
    description = string
  }))
}

variable "ssh_user" {
  description = "Пользователь для SSH подключения"
  type        = string
  default     = "ubuntu"
} 