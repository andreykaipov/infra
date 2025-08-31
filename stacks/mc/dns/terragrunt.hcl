include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cloudflare" {
  path = "${get_repo_root()}/providers/cloudflare.hcl"
}

dependency "proxy" {
  config_path = "../proxy"
}

terraform {
  source = "./"
}

inputs = {
  dependencies = {
    proxy = dependency.proxy
  }
}
