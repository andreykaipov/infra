locals {
  common = read_terragrunt_config(find_in_parent_folders("root.common.hcl")).locals
}

terraform {
  source = "${local.common.root}/modules/docker-image"
}

inputs = {
  image_name    = "ghcr.io/${local.common.repo}/${local.common.relative_path}"
  image_tag     = "latest"
  build_context = get_terragrunt_dir()

  labels = {
    "org.opencontainers.image.authors" = "${local.common.user}"
    "org.opencontainers.image.source"  = "https://github.com/${local.common.repo}"
    "org.opencontainers.image.url"     = "https://github.com/${local.common.repo}/tree/main/${local.common.relative_path}"
    # "org.opencontainers.image.created"     = timestamp()
  }

  # by default the rebuild triggers are on **/* so we want to keep this narrowed down
  source_files_pattern = "**/*.go"

  registry_url = "ghcr.io"
  registry_auth = {
    username = local.common.secrets.github.username
    password = local.common.secrets.github.ghcr_pat
  }
}
