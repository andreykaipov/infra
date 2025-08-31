variable "dependencies" {
  type = map(any)
}

locals {
  cf_account_id = local.secrets.setup["cloudflare_account_id"]
}

data "cloudflare_zone" "zone" {
  filter = {
    name = "zvigelsky.com"
  }
}

resource "cloudflare_dns_record" "dota2" {
  zone_id = data.cloudflare_zone.zone.zone_id
  type    = "CNAME"
  name    = "dota2"
  content = var.dependencies.proxy.outputs.fqdn
  proxied = false
  ttl     = 1
}
