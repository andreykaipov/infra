generate "provider_azure" {
  path      = "zz_generated.provider.azure.tf"
  if_exists = "overwrite"
  contents  = <<EOF
provider "azurerm" {
  features {}
  client_id       = local.secrets.setup.az_service_principal.appId
  client_secret   = local.secrets.setup.az_service_principal.password
  tenant_id       = local.secrets.setup.az_service_principal.tenantId
  subscription_id = local.secrets.setup.az_service_principal.subscriptionId
}
EOF
}

generate "provider_azure_override" {
  path      = "zz_generated.provider.azure._override.tf"
  if_exists = "overwrite"
  contents  = <<EOF
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}
EOF
}
