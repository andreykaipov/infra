generate "provider_cloudflare" {
  path      = "zz_generated.provider.cloudflare.tf"
  if_exists = "overwrite"
  contents  = <<EOF
provider "cloudflare" {
  api_token = local.secrets.setup.cloudflare_api_token
}
EOF
}

generate "provider_cloudflare_override" {
  path      = "zz_generated.provider.cloudflare._override.tf"
  if_exists = "overwrite"
  contents  = <<EOF
terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}
EOF
}
