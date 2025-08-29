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

