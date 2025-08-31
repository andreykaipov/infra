locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl")).locals
}

terraform {
  source = "${local.root.root}/modules/docker-image"
}

inputs = {
  name          = "ghcr.io/${local.root.repo}/${local.root.relative_path}"
  tag           = "latest"
  build_context = get_terragrunt_dir()

  labels = {
    "org.opencontainers.image.authors" = "${local.root.user}"
    "org.opencontainers.image.source"  = "https://github.com/${local.root.repo}"
    "org.opencontainers.image.url"     = "https://github.com/${local.root.repo}/tree/main/${local.root.relative_path}"
    # "org.opencontainers.image.created"     = timestamp()
  }

  # by default the rebuild triggers are on **/* so we want to keep this narrowed down
  source_files_pattern = "**/*.go"

  registry_url = "ghcr.io"
  registry_auth = {
    username = local.root.secrets.github.username
    password = local.root.secrets.github.ghcr_pat
  }
}
