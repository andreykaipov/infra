locals {
  subdomain_routes = merge(
    local.resume_routes,
    {
      # www redirect with workers to conserve page rules :)
      "www"  = { to = "https://${cloudflare_zone.kaipov.name}", preserve_path = true }
      "call" = { to = "https://calendly.com/kaipov/call", preserve_path = true }
    }
  )

  path_routes = merge(local.resume_routes, {})

  # For the neat links in our resume, used in both subdomain and path routes
  # since I can't decide which one I like yet.
  resume_routes = {
    for k, v in var.resume_project_routes :
    k => { to = v }
  }
}

### subdomain routes, e.g. blah.kaipov.com/*

resource "cloudflare_workers_script" "subdomain_routes" {
  account_id  = local.cf_account_id
  for_each    = local.subdomain_routes
  script_name = "301-${each.key}"
  content = templatefile("js/redirect-301.js.tmpl", {
    base          = each.value.to
    preserve_path = try(each.value.preserve_path, false)
  })
}

resource "cloudflare_workers_route" "subdomain_routes" {
  for_each = local.subdomain_routes
  zone_id  = cloudflare_zone.kaipov.id
  pattern  = "${each.key}.${cloudflare_zone.kaipov.name}/*"
  script   = cloudflare_workers_script.subdomain_routes[each.key].script_name
}

resource "cloudflare_dns_record" "subdomain_routes" {
  for_each = local.subdomain_routes
  zone_id  = cloudflare_zone.kaipov.id
  name     = "${each.key}.${cloudflare_zone.kaipov.name}"
  type     = "CNAME"
  content  = cloudflare_zone.kaipov.name
  proxied  = true
  ttl      = 1
}

### path routes, e.g. kaipov.com/blah*

resource "cloudflare_workers_script" "path_routes" {
  account_id  = local.cf_account_id
  for_each    = local.path_routes
  script_name = "301-${each.key}-path"
  content = templatefile("js/redirect-301.js.tmpl", {
    base          = each.value.to
    preserve_path = try(each.value.preserve_path, false)
  })
}

resource "cloudflare_workers_route" "path_routes" {
  for_each = local.path_routes
  zone_id  = cloudflare_zone.kaipov.id
  pattern  = "${cloudflare_zone.kaipov.name}/${each.key}*"
  script   = cloudflare_workers_script.subdomain_routes[each.key].script_name
}
