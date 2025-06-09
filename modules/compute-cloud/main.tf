locals {
  ssh_processed_servers = {
    for server_name, server_config in var.servers_config : server_name => {
      is_public = server_config.is_public
      cores     = server_config.cores
      memory    = server_config.memory
      disk_size = server_config.disk_size
      image_id  = server_config.image_id
      sg_config = {
        ingress_rules = [
          for rule in server_config.sg_config.ingress_rules : {
            protocol          = rule.protocol
            port_range        = rule.port_range
            predefined_target = rule.predefined_target
            cidr_blocks       = (rule.port_range.from == 22 && rule.port_range.to == 22) ? [for ssh_rule in var.ssh_access_rules : ssh_rule.ip_address] : rule.cidr_blocks
            description       = rule.description
          }
        ]
        egress_rules = server_config.sg_config.egress_rules
      }
    }
  }
}

resource "yandex_vpc_security_group" "server_sg" {
  for_each   = var.servers_config
  name       = "${each.key}-sg"
  network_id = var.network_id

  dynamic "ingress" {
    for_each = local.ssh_processed_servers[each.key].sg_config.ingress_rules
    content {
      protocol          = ingress.value.protocol
      from_port         = ingress.value.port_range.from
      to_port           = ingress.value.port_range.to
      predefined_target = ingress.value.predefined_target
      v4_cidr_blocks    = ingress.value.cidr_blocks
      description       = ingress.value.description
    }
  }

  dynamic "egress" {
    for_each = local.ssh_processed_servers[each.key].sg_config.egress_rules
    content {
      protocol          = egress.value.protocol
      from_port         = egress.value.port_range.from
      to_port           = egress.value.port_range.to
      predefined_target = egress.value.predefined_target
      v4_cidr_blocks    = egress.value.cidr_blocks
      description       = egress.value.description
    }
  }
}

resource "yandex_compute_disk" "server_disk" {
  for_each = var.servers_config
  name     = "${each.key}-disk"
  size     = each.value.disk_size
  zone     = var.zone
  image_id = each.value.image_id
}

resource "yandex_compute_instance" "servers" {
  for_each    = var.servers_config
  name        = each.key
  zone        = var.zone
  platform_id = "standard-v3"

  resources {
    cores  = each.value.cores
    memory = each.value.memory
  }

  boot_disk {
    disk_id = yandex_compute_disk.server_disk[each.key].id
  }

  network_interface {
    subnet_id          = each.value.is_public ? var.public_subnet_id : var.private_subnet_id
    nat                = each.value.is_public
    security_group_ids = [yandex_vpc_security_group.server_sg[each.key].id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
} 
