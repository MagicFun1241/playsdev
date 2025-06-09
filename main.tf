provider "yandex" {
  zone = var.default_zone
}

module "vpc" {
  source = "./modules/vpc"
  
  vpc_name           = var.vpc_name
  public_subnet_cidr = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  zone              = var.default_zone
}

module "postgres" {
  source = "./modules/postgres"
  
  count = var.enable_postgres ? 1 : 0
  
  db_name        = var.db_name
  db_user        = var.db_user
  db_password    = var.db_password

  network_id     = module.vpc.vpc_id
  subnet_id      = module.vpc.private_subnet_id
  zone          = var.default_zone
}

module "compute-cloud" {
  source = "./modules/compute-cloud"
  
  servers_config = var.servers_config
  network_id     = module.vpc.vpc_id

  public_subnet_id = module.vpc.public_subnet_id
  private_subnet_id = module.vpc.private_subnet_id

  zone          = var.default_zone

  ssh_access_rules = var.ssh_access_rules
  ssh_user         = var.ssh_user
} 