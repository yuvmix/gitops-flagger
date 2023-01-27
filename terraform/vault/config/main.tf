terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = ">= 3.10"
    }
  }
}

provider "vault" {
  address         = "http://vault.vault.svc:8200"
  token           = "root"
  skip_tls_verify = true
}