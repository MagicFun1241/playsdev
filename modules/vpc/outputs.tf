output "vpc_id" {
  description = "ID VPC"
  value       = yandex_vpc_network.main.id
}

output "public_subnet_id" {
  description = "ID публичной подсети"
  value       = yandex_vpc_subnet.public.id
}

output "private_subnet_id" {
  description = "ID приватной подсети"
  value       = yandex_vpc_subnet.private.id
}

output "public_subnet_cidr" {
  description = "CIDR публичной подсети"
  value       = var.public_subnet_cidr
}

output "private_subnet_cidr" {
  description = "CIDR приватной подсети"
  value       = var.private_subnet_cidr
} 