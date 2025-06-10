variable "db_name" {
  description = "Имя базы данных"
  type        = string
}

variable "db_user" {
  description = "Пользователь базы данных"
  type        = string
}

variable "db_password" {
  description = "Пароль базы данных"
  type        = string
  sensitive   = true
}

variable "network_id" {
  description = "ID сети"
  type        = string
}

variable "subnet_id" {
  description = "ID подсети для размещения PostgreSQL"
  type        = string
}

variable "zone" {
  description = "Зона размещения"
  type        = string
} 