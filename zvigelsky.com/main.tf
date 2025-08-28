locals {
  cf_account_id = local.secrets.setup["cloudflare_account_id"]
}

resource "cloudflare_zone" "zone" {
  account = { id = local.cf_account_id }
  name    = "zvigelsky.com"
  type    = "full"
}

resource "cloudflare_zone_setting" "setting" {
  for_each = {
    # SSL/TLS
    ssl                      = "full"
    always_use_https         = "on"
    min_tls_version          = "1.0"
    opportunistic_encryption = "on"
    tls_1_3                  = "zrt" # zero rtt below
    automatic_https_rewrites = "on"

    # Other security things
    challenge_ttl  = 1800
    security_level = "high"
    privacy_pass   = "on"

    # Speed
    brotli = "on"

    # Caching
    cache_level       = "aggressive"
    browser_cache_ttl = 0
    always_online     = "off"

    # Network
    http3               = "on"
    websockets          = "on"
    opportunistic_onion = "on"
    ip_geolocation      = "on"

    # Scrape shield
    email_obfuscation   = "on"
    server_side_exclude = "on"
  }

  zone_id    = cloudflare_zone.zone.id
  setting_id = each.key
  value      = each.value
}
