default_zone = "ru-central1-a"
vpc_name     = "main-vpc"

public_subnet_cidr  = "10.0.1.0/24"
private_subnet_cidr = "10.0.2.0/24"

db_name     = "main_db"
db_user     = "magicfun"
db_password = "magicfun"

ssh_access_rules = {
  "my_home" = {
    ip_address  = "176.124.203.177/32"
    description = "My home IP"
  }
}

servers_config = {
  "bastion" = {
    is_public = true
    cores     = 2
    memory    = 2
    disk_size = 10
    image_id  = "fd82up3o0u6o36dbto2h"
    sg_config = {
      ingress_rules = [
        {
          protocol = "TCP"
          port_range = {
            from = 22
            to   = 22
          }
          cidr_blocks = ["0.0.0.0/0"]  # Будет заменено на IP из ssh_access_rules
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
          cidr_blocks = ["0.0.0.0/0"]
          description = "All outbound traffic"
        }
      ]
    }
  }

   "demo" = {
    is_public = true
    cores     = 2
    memory    = 2
    disk_size = 10
    image_id  = "fd82up3o0u6o36dbto2h"
    sg_config = {
      ingress_rules = [
        {
          protocol = "TCP"
          port_range = {
            from = 22
            to   = 22
          }
          cidr_blocks = ["0.0.0.0/0"]  # Будет заменено на IP из ssh_access_rules
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
          cidr_blocks = ["0.0.0.0/0"]
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
    image_id  = "fd82up3o0u6o36dbto2h"
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
        },
        {
          protocol = "TCP"
          port_range = {
            from = 80
            to   = 80
          }
          cidr_blocks = ["10.0.0.0/16"]
          description = "HTTP access from VPC"
        }
      ]
      egress_rules = [
        {
          protocol = "ANY"
          port_range = {
            from = 0
            to   = 65535
          }
          cidr_blocks = ["0.0.0.0/0"]
          description = "All outbound traffic"
        }
      ]
    }
  }
}

enable_postgres = true