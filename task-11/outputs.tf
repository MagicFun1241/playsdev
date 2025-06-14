output "vpc_info" {
  description = "Информация о VPC"
  value = {
    vpc_id            = module.vpc.vpc_id
    public_subnet_id  = module.vpc.public_subnet_id
    private_subnet_id = module.vpc.private_subnet_id
  }
}

output "servers_info" {
  description = "Информация о серверах"
  value       = module.compute-cloud.servers_info
}

output "bastion_external_ip" {
  description = "Внешний IP bastion хоста"
  value       = module.compute-cloud.bastion_external_ip
}

output "postgres_info" {
  description = "Информация о PostgreSQL"
  value       = var.enable_postgres ? module.postgres[0].postgres_info : null
  sensitive   = true
} 