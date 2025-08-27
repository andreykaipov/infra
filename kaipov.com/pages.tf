locals {
  custom_domain = cloudflare_zone.kaipov.name
  project_name  = replace(lower(local.custom_domain), "/[^a-z0-9-]+/", "-")
}

resource "cloudflare_dns_record" "pages" {
  zone_id = cloudflare_zone.kaipov.id
  name    = local.custom_domain
  type    = "CNAME"
  content = cloudflare_pages_project.website.subdomain
  proxied = true
  ttl     = 1
}

resource "cloudflare_pages_domain" "domain" {
  account_id   = local.cf_account_id
  project_name = cloudflare_pages_project.website.name
  name         = local.custom_domain
}

resource "cloudflare_pages_project" "website" {
  account_id        = local.cf_account_id
  name              = local.project_name
  production_branch = "main"

  source = {
    type = "github"
    config = {
      owner                          = "andreykaipov"
      repo_name                      = "website"
      production_branch              = "main"
      pr_comments_enabled            = true
      deployments_enabled            = true
      production_deployment_enabled  = true
      preview_deployment_setting     = "all"
      path_excludes                  = []
      path_includes                  = ["*"]
      preview_branch_excludes        = []
      preview_branch_includes        = ["*"]
      production_deployments_enabled = true
    }
  }

  build_config = {
    build_command   = "hugo"
    destination_dir = "public"
    build_caching   = false
  }

  deployment_configs = {
    preview = {
      compatibility_date  = "2025-08-27"
      compatibility_flags = []
    }
    production = {
      compatibility_date  = "2025-08-27"
      compatibility_flags = []
    }
  }

  lifecycle {
    ignore_changes = [
    ]
  }
}
