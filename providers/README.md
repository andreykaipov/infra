For any Terragrunt modules not invoking Terraform modules and instead containing Terraform code, use the provider generation snippets in this folder to configure the Terragrunt module correctly.

For example, in a Terragrunt module's `terragrunt.hcl`:

```hcl
include "azure" {
  path = "${get_repo_root()}/providers/azure.hcl"
}
```

Normally Terraform does not like duplicate required providers in its configuration, which is why it's imperative we suffix generated files containing that kind of configuration with `_override.tf` so Terraform can specially handle them and merge them together. See https://developer.hashicorp.com/terraform/language/files/override for more details.
