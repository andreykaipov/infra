terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 2.0"
    }
  }
}

locals {
  zone = "kaipov.com"
}

resource "cloudflare_zone" "kaipov" {
  zone       = local.zone
  plan       = "free"
  type       = "full"
  paused     = false
  jump_start = false
}

resource "cloudflare_zone_settings_override" "kaipov" {
  zone_id = cloudflare_zone.kaipov.id
  settings {
    # SSL/TLS
    ssl                      = "full"
    always_use_https         = "on"
    min_tls_version          = "1.0"
    opportunistic_encryption = "on"
    tls_1_3                  = "on"
    automatic_https_rewrites = "on"

    # Speed
    minify {
      css  = "on"
      js   = "on"
      html = "on"
    }
    brotli = "on"

    # Caching
    cache_level       = "aggressive"
    browser_cache_ttl = 0
    always_online     = "off"
  }
}

resource "cloudflare_record" "pages" {
  zone_id = cloudflare_zone.kaipov.id
  name    = local.zone
  type    = "CNAME"
  value   = "kaipov.pages.dev"
  proxied = true
  ttl     = 1
}
