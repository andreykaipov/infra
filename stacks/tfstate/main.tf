locals {
  cf_account_id = local.secrets.setup["cloudflare_account_id"]
}

resource "cloudflare_workers_kv_namespace" "tfstate" {
  account_id = local.cf_account_id
  title      = "tfstate"
}

resource "cloudflare_workers_script" "tfstate" {
  account_id  = local.cf_account_id
  script_name = "tfstate-handler"
  content     = file("index.js")
  main_module = "worker.js"
  # we want the bindings to be sorted by name to guarantee idempotency, and
  # mapping from a map to a list implicitly sorts the objects by the name key
  bindings = [
    for k, v in {
      username = {
        type = "secret_text"
        text = local.secrets.setup["tf_backend_username"]
      }
      password = {
        type = "secret_text"
        text = local.secrets.setup["tf_backend_password"]
      }
      (cloudflare_workers_kv_namespace.tfstate.title) = {
        type         = "kv_namespace"
        namespace_id = cloudflare_workers_kv_namespace.tfstate.id
      }
  } : merge(v, { name = k })]
}

data "cloudflare_zone" "kaipov" {
  filter = {
    name = "kaipov.com"
  }
}

resource "cloudflare_workers_route" "terraform_route" {
  zone_id = data.cloudflare_zone.kaipov.zone_id
  pattern = "tf.${data.cloudflare_zone.kaipov.name}/*"
  script  = cloudflare_workers_script.tfstate.script_name
}
