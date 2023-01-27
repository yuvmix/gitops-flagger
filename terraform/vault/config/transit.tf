resource "vault_mount" "transit" {
  path = "transit"
  type = "transit"
}

resource "vault_transit_secret_backend_key" "my-key" {
  backend = vault_mount.transit.path
  name    = "my-key"
}
