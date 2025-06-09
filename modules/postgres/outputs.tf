output "postgres_info" {
  description = "Информация о PostgreSQL кластере"
  value = {
    cluster_id = yandex_mdb_postgresql_cluster.postgres.id
    host       = yandex_mdb_postgresql_cluster.postgres.host[0].fqdn
    port       = 6432
    database   = yandex_mdb_postgresql_database.db.name
    user       = yandex_mdb_postgresql_user.user.name
  }
  sensitive = true
}

output "cluster_id" {
  description = "ID PostgreSQL кластера"
  value       = yandex_mdb_postgresql_cluster.postgres.id
} 