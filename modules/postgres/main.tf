resource "yandex_mdb_postgresql_cluster" "postgres" {
  name        = var.db_name
  environment = "PRODUCTION"
  network_id  = var.network_id

  config {
    version = 17
    resources {
      resource_preset_id = "b2.medium"
      disk_type_id       = "network-hdd"
      disk_size          = 10
    }
  }

  host {
    zone      = var.zone
    subnet_id = var.subnet_id
  }
}

resource "yandex_mdb_postgresql_database" "db" {
  cluster_id = yandex_mdb_postgresql_cluster.postgres.id
  name       = var.db_name
  owner      = yandex_mdb_postgresql_user.user.name
}

resource "yandex_mdb_postgresql_user" "user" {
  cluster_id = yandex_mdb_postgresql_cluster.postgres.id
  name       = var.db_user
  password   = var.db_password
}
