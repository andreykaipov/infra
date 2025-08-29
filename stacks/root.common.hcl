# helpful to keep this in its own file separate from the generate blocks, so we
# can import it in child terragrunt modules without importing the entire root  

locals {
  user         = "andreykaipov"                        # hey it's me
  root         = get_repo_root()                       # /home/blah/blah/infra
  project_name = basename(local.root)                  # infra
  repo         = "${local.user}/${local.project_name}" # andreykaipov/infra

  # we can't use get_path_from_repo_root() here because this config is read from root.hcl
  # and would return the relative path to itself, instead of where Terragrunt was invoked
  invoked_tg_dir = get_original_terragrunt_dir() # /home/blah/blah/infra/stacks/a/b/c

  # only things in infra/stacks have state, so we can trim the common prefix
  relative_path = trimprefix(local.invoked_tg_dir, "${local.root}/") # stacks/a/b/c
  tfstate_id    = trimprefix(local.relative_path, "stacks/")         # a/b/c

  self_secrets_val = get_env("self_secrets")
  self_secrets = try(
    jsondecode(local.self_secrets_val),
    run_cmd("sh", "-c", <<EOF
      echo "There was an issue parsing self_secrets:"
      echo '${local.self_secrets_val}'
    EOF
    )
  )

  secrets = local.self_secrets
}
