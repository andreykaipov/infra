locals {
  name = "gochujang"
}

# debug with:
# az containerapp logs show --follow -n gochujang -g gochujang-rg
# az containerapp exec -n gochujang -g gochujang-rg --command sh

module "app" {
  source = "./azure-container-app"

  name     = local.name
  location = "eastus"
  image    = "ghcr.io/andreykaipov/discord-bots/go/chatbot"
  sha      = "sha256:8c67b9b88fbb099062b7613d8ea669442ad5eed5c85f9996e006eb0a7e1ef366"

  env = {
    DISCORD_TOKEN                 = "secret://${local.secrets[local.name].discord_token}",
    CHAT_CHANNEL                  = "1189812317043568640",
    MGMT_CHANNEL                  = "1191195268343939082",
    OPENAI_API_KEY                = "secret://${local.secrets[local.name].openai_api_key}",
    MODEL                         = "ft:gpt-3.5-turbo-1106:personal::8acg6lzo",
    TEMPERATURE                   = "0.95",
    TOP_P                         = "1",
    PROMPTS                       = "/shared/prompts.yml",
    USERS                         = "/shared/users.json",
    MESSAGE_CONTEXT               = "30",
    MESSAGE_CONTEXT_INTERVAL      = "60",
    MESSAGE_REPLY_INTERVAL        = "1",
    MESSAGE_REPLY_INTERVAL_JITTER = "4",
    MESSAGE_SELF_REPLY_CHANCE     = "10",
  }

  files = {
    "prompts.yml" = file("config/prompts.yml")
    "users.json"  = file("config/users.json")
  }
}
