output "servers_info" {
  description = "Информация о серверах"
  value = {
    for server_name, server in yandex_compute_instance.servers : server_name => {
      id          = server.id
      internal_ip = server.network_interface.0.ip_address
      external_ip = server.network_interface.0.nat_ip_address
      zone        = server.zone
      status      = server.status
    }
  }
  sensitive = true
}

output "security_groups" {
  description = "Идентификаторы Security Groups"
  value = {
    for sg_name, sg in yandex_vpc_security_group.server_sg : sg_name => sg.id
  }
}

output "bastion_external_ip" {
  description = "Внешний IP bastion хоста"
  value = try(yandex_compute_instance.servers["bastion"].network_interface.0.nat_ip_address, null)
}

output "disks_info" {
  description = "Информация о дисках"
  value = {
    for disk_name, disk in yandex_compute_disk.server_disk : disk_name => {
      id   = disk.id
      size = disk.size
      zone = disk.zone
    }
  }
} 