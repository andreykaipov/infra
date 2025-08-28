terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

variable "account_id" {
  type        = string
  description = "The Cloudflare account ID to use."
}

variable "zone" {
  type = object({
    id   = string
    name = string
  })
  description = <<EOF
An object containing the zone ID and zone name for the Cloudflare zone to use.
You can pass the cloudflare_zone resource or data.cloudflare_zone data source to
this variable directly.
EOF
}

variable "name" {
  type        = string
  description = "An identifying name for the worker script."
}

variable "script" {
  type        = string
  description = <<EOF
The content of your worker script, or a path to a file containing the script.
EOF
}

variable "with_itty" {
  type        = bool
  default     = false
  description = <<EOF
If true, the worker script will be prepended with the minified contents of
[itty-router](https://github.com/kwhitley/itty-router) and additional helpers so
that we can write our worker script as follows:

```js
export default server((r) => {
    r.get('/:name', (request, env, ctx) => {
        const name = request.params.name
        return new Response(`Hello $${name}!`)
    })
}, (env, ctx) => {
    console.log("cron scheduled event callback")
})
```
EOF
}

variable "module" {
  type        = bool
  default     = true
  description = "Whether to upload the script as an ES6 module."
}

variable "bindings" {
  type = list(object({
    name         = string
    type         = string
    bucket_name  = optional(string)
    dataset      = optional(string)
    environment  = optional(string)
    json         = optional(string)
    namespace    = optional(string)
    namespace_id = optional(string)
    service      = optional(string)
    text         = optional(string)
  }))
  default     = []
  description = "A list of bindings to bindg to the worker script."
}

variable "cron_schedules" {
  type        = set(string)
  default     = []
  description = <<EOF
Execute your worker script on these reoccurring cron schedules. You'll also need
to pass the scheduled event callback to your worker script. See `var.script` for
more details. Wraps the `cloudflare_worker_cron_trigger` resource.
EOF
}

variable "routes" {
  type        = set(string)
  default     = []
  description = <<EOF
An optional set of route patterns to bind to the worker script.
https://developers.cloudflare.com/workers/configuration/routing/
EOF
}

variable "domains" {
  type        = set(string)
  default     = []
  description = <<EOF
An optional set of custom domains to bind to the worker script.
https://developers.cloudflare.com/workers/configuration/routing/
EOF
}

variable "kv" {
  type        = map(map(string))
  default     = {}
  description = <<EOF
An optional map of KV namespaces and any key/value pairs you'd like to seed the
KV namespaces with. This is a wrapper to the `cloudflare_workers_kv_namespace`
and `cloudflare_workers_kv` resources.

Example specification:

kv = {
  kv1 = {
    key1 = "value1"
    key2 = "value2"
  }
  kv2 = {
    key1 = "value1"
    key2 = "value2"
  }
}
EOF
}

locals {
  script  = try(file(var.script), var.script)
  content = var.with_itty ? "${file("${path.module}/lib.js")}\n${local.script}" : local.script
}

resource "cloudflare_workers_script" "script" {
  account_id  = var.account_id
  script_name = replace("${var.zone.name}-${var.name}", "/[^a-zA-Z0-9-]/", "-")
  content     = local.content
  main_module = "worker.js"
  bindings    = var.bindings
}

resource "cloudflare_workers_cron_trigger" "trigger" {
  count       = length(var.cron_schedules) > 0 ? 1 : 0
  account_id  = var.account_id
  script_name = cloudflare_workers_script.script.script_name
  schedules = [
    for schedule in var.cron_schedules :
    { cron = schedule }
  ]
}

resource "cloudflare_workers_route" "route" {
  for_each = var.routes
  zone_id  = var.zone.id
  pattern  = each.value
  script   = cloudflare_workers_script.script.script_name
}

resource "cloudflare_workers_custom_domain" "custom_domain" {
  for_each    = var.domains
  account_id  = var.account_id
  zone_id     = var.zone.id
  hostname    = each.key
  service     = cloudflare_workers_script.script.script_name
  environment = "production"
}

resource "cloudflare_workers_kv_namespace" "kv_namespace" {
  for_each   = var.kv
  account_id = var.account_id
  title      = each.key
}

resource "cloudflare_workers_kv" "kv_entry" {
  for_each     = toset(flatten([for kv, entry in var.kv : [for k, v in entry : [kv, k, v]]]))
  account_id   = var.account_id
  namespace_id = cloudflare_workers_kv_namespace.kv_namespace[each.value[0]].id
  key_name     = each.value[1]
  value        = each.value[2]
}
