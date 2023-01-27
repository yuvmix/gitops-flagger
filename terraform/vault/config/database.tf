resource "vault_mount" "db" {
  path = "database"
  type = "database"
}

resource "vault_database_secret_backend_connection" "mongodb" {
  backend           = vault_mount.db.path
  name              = "mongodb"
  allowed_roles     = ["webapp"]
  plugin_name       = "mongodb-database-plugin"
  verify_connection = false

  mongodb {
    connection_url = "mongodb://{{username}}:{{password}}@database-mongodb.prod.svc:27017/admin?tls=false"
    username       = "root"
    password       = "willBeChangedByVault"
  }
}

resource "vault_database_secret_backend_role" "role" {
  backend             = vault_mount.db.path
  name                = "webapp"
  db_name             = vault_database_secret_backend_connection.mongodb.name
  creation_statements = ["{\"db\": \"my_database\", \"roles\": [{\"role\": \"readWrite\"}]}"]
  default_ttl         = 3600
  max_ttl             = 86400
}
