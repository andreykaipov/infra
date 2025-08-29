retry_max_attempts       = 3
retry_sleep_interval_sec = 10

locals {
  common = read_terragrunt_config(find_in_parent_folders("root.common.hcl")).locals

  root       = local.common.root
  tfstate_id = local.common.tfstate_id
  secrets    = local.common.secrets

  # _ = run_cmd("bash", "-c", <<EOF
  # echo '${local.root}'
  # echo '${local.tfstate_id}'
  # echo '${get_path_from_repo_root()}'
  # EOF
  # )

  providers = try(read_terragrunt_config("providers.hcl").locals.providers, [])
}

inputs = {
  __secrets = local.secrets
}

terraform {
  source = "${local.root}/modules//"
}

remote_state {
  generate = {
    path      = "zz_generated.backend.tf"
    if_exists = "overwrite"
  }

  backend = "http"
  config = {
    username       = local.secrets.setup.tf_backend_username
    password       = local.secrets.setup.tf_backend_password
    address        = "https://tf.kaipov.com/${local.tfstate_id}"
    lock_address   = "https://tf.kaipov.com/${local.tfstate_id}"
    unlock_address = "https://tf.kaipov.com/${local.tfstate_id}"
  }
}

// pass secrets to our terragrunt modules
generate "secrets" {
  path      = "zz_generated.secrets.tf"
  if_exists = "overwrite"
  contents  = <<EOF
variable "__secrets" {
  type      = string
  sensitive = true
}

locals {
  secrets = sensitive(jsondecode(var.__secrets))
}
EOF
}

# declare providers based on contents of providers.hcl in child modules.
# in case our terragrunt module declares their own providers, we use the
# override directive to avoid conflicts:
# https://developer.hashicorp.com/terraform/language/files/override
generate "provider_override" {
  path      = "zz_generated.provider_override.tf"
  if_exists = "overwrite"
  contents  = <<EOF
terraform {
  required_providers {
    %{~if contains(local.providers, "azure")~}
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    %{~endif~}
    %{~if contains(local.providers, "cloudflare")~}
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    %{~endif~}
    %{~if contains(local.providers, "onepassword")~}
    onepassword = {
      source  = "1Password/onepassword"
      version = "~> 2.0"
    }
    %{~endif~}
    %{~if contains(local.providers, "docker")~}
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    %{~endif~}
  }
}

%{~if contains(local.providers, "azure")}
provider "azurerm" {
  features {}
  client_id                  = local.secrets.setup.az_service_principal.appId
  client_secret              = local.secrets.setup.az_service_principal.password
  tenant_id                  = local.secrets.setup.az_service_principal.tenantId
  subscription_id            = local.secrets.setup.az_service_principal.subscriptionId
}
%{~endif}

%{~if contains(local.providers, "cloudflare")}
provider "cloudflare" {
  api_token = local.secrets.setup.cloudflare_api_token
}
%{~endif}

%{~if contains(local.providers, "onepassword")}
provider "onepassword" {
  // set via OP_SERVICE_ACCOUNT_TOKEN env var
  // it's how we got all the other secrets
}
%{~endif}
EOF
}
