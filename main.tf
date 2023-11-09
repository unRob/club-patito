terraform {
  backend "consul" {
    path = "nidito/state/service/club-patito"
  }

  required_providers {
    acme = {
      source  = "vancluever/acme"
      version = "~> 2.15.1"
    }

    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "~> 2.29.0"
    }

    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.18.0"
    }
  }

  required_version = ">= 1.0.0"
}

locals {
  policies = {
    "sys/capabilities-self" = ["update"]
    "auth/token/renew-self" = ["update"]
    "config/kv/provider:cdn" = ["read"]
    "config/kv/pati.to:club" = ["read"]
    "cfg/infra/tree/provider:cdn" = ["read"]
    "cfg/svc/tree/pati.to:club" = ["read"]
  }

  mx_servers = {
    "mxa.mailgun.org." = 10,
    "mxb.mailgun.org." = 10,
  }
}

provider "acme" {
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}

// DO tokens for compute resources
data "vault_generic_secret" "DO" {
  path = "cfg/infra/tree/provider:digitalocean"
}

provider "digitalocean" {
  token = data.vault_generic_secret.DO.data.patito
}

data "terraform_remote_state" "rob_mx" {
  backend = "consul"
  workspace = "default"
  config = {
    datacenter = "casa"
    path = "nidito/state/rob.mx"
  }
}

resource "vault_policy" "service" {
  name = "club-patito"
  policy = <<-HCL
  %{ for path in sort(keys(local.policies)) }path "${path}" {
    capabilities = ${jsonencode(local.policies[path])}
  }

  %{ endfor }
  HCL
}

resource "digitalocean_record" "to_pati_club" {
  domain = "pati.to"
  type   = "A"
  ttl    = 3600
  name   = "club"
  value  = data.terraform_remote_state.rob_mx.outputs.bernal.ip
}

resource "digitalocean_record" "txt_smtp_domainkey" {
  domain = "pati.to"
  type   = "TXT"
  name   = "mailo._domainkey.mail.club"
  value  = "k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDG2sUJLqDOqMnjMy3+fNI0rdrGb8VrI84yloaXE9R8aLEXkm0jlANiFEmVF7s7ZvoDoKm0v5Lm/JsvM/Rl8n9TS2QYMqhmVsEmuBHwOVhekUDW/LKvfDxfNhmbquvU4z+/fn2WBx19dLG3Ctao7pbL7B9TKR+sPJUNoFWRseucMQIDAQAB"
}

resource "digitalocean_record" "txt_spf" {
  domain = "pati.to"
  type   = "TXT"
  name   = "mail.club"
  value  = "v=spf1 include:mailgun.org ~all;"
}

resource "digitalocean_record" "mx" {
  for_each = local.mx_servers
  domain   = "pati.to"
  type     = "MX"
  name     = "mail.club"
  value    = each.key
  priority = each.value
}

