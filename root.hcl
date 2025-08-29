retry_max_attempts       = 3
retry_sleep_interval_sec = 10

locals {
  user    = "andreykaipov"                   # hey it's me
  root    = get_repo_root()                  # /home/blah/blah/infra
  project = basename(local.root)             # infra
  repo    = "${local.user}/${local.project}" # andreykaipov/infra

  # we can't use get_path_from_repo_root() for the relative path because if `root.hcl` is read
  # by `read_terragrunt_config` (e.g. like in `docker-image.hcl`), the relative path will be `.`,
  # which is inconsistent when finding the relative path to the dir where Terragrunt was invoked
  invoked_tg_dir = get_original_terragrunt_dir()                      # /home/blah/blah/infra/stacks/a/b/c
  relative_path  = trimprefix(local.invoked_tg_dir, "${local.root}/") # stacks/a/b/c
  tfstate_id     = "${local.project}/${local.relative_path}"          # infra/stacks/a/b/c

  secrets_val = get_env("secrets")
  secrets = try(
    jsondecode(local.secrets_val),
    run_cmd("sh", "-c", <<EOF
      echo "There was an issue parsing secrets:"
      echo '${local.secrets_val}'
    EOF
    )
  )
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

# Makes secrets available as a local variable in any Terragrunt modules that
# want to write Terraform directly instead of invoking modules. For any TG
# modules invoking TF modules, they would need to expose the root includes.
inputs = {
  __secrets = local.secrets
}

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

# Copies all modules to the.terragrunt-cache dir. A Terragrunt module
# can still specify only one module, but this is handy if a Terragrunt
# module ever needs access to several modules at once
# (without having to create a separate Terraform module).
terraform {
  source = "${local.root}/modules//"
}
