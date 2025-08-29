include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "docker" {
  path = "../docker-image.hcl"
}
