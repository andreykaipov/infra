include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  providers = ["cloudflare"]

  resume_tex = "${include.root.locals.root}/resume/resume.tex"

  resume = {
    projects = [
      "self",
      "goobs",
      "env2conf",
      "mongodb-pool",
      "funcopgen",
      "tf-chef-solo",
      "active-standby",
    ]

    links = [
      "https://github.com/andreykaipov/self",
      "https://github.com/andreykaipov/goobs",
      "https://github.com/andreykaipov/env2conf",
      "https://github.com/andreykaipov/mongodb-pool",
      "https://github.com/andreykaipov/funcopgen",
      "https://github.com/andreykaipov/terraform-provisioner-chef-solo",
      "https://github.com/andreykaipov/active-standby-controller",
    ]
  }
}

inputs = {
  resume_project_routes = zipmap(
    local.resume.projects,
    local.resume.links,
  )
}
