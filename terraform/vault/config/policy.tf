resource "vault_policy" "webapp" {
  name = "webapp"

  policy = <<EOT
path "database/creds/webapp" {
  capabilities = ["read"]
}

path "transit/+/my-key" {
  capabilities = ["create", "read", "update", "list"]
}
EOT
}
