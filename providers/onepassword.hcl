generate "provider_onepassword" {
  path      = "zz_generated.provider.onepassword.tf"
  if_exists = "overwrite"
  contents  = <<EOF
provider "onepassword" {
  // set via OP_SERVICE_ACCOUNT_TOKEN env var
  // it's how we got all the other secrets
}
EOF
}

generate "provider_onepassword_override" {
  path      = "zz_generated.provider.onepassword._override.tf"
  if_exists = "overwrite"
  contents  = <<EOF
terraform {
  required_providers {
    onepassword = {
      source  = "1Password/onepassword"
      version = "~> 2.0"
    }
  }
}
EOF
}
