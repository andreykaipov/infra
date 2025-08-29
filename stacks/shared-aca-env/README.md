# Shared Azure Container App Environment

This creates a shared Azure Container App Environment that can be used by any project requiring containerized applications on Azure.

## Features

- **Custom VNET**: Enables external TCP/UDP access for any protocol
- **Network Security Group**: Pre-configured with common application ports
- **Reusable**: Can be referenced by any container app across different projects
- **Cost Effective**: Deploy once, use many times

## Included Ports

- HTTP (8080), Custom TCP (3000, 5000)
- Minecraft (25565, 25575) 
- Database (5432), Redis (6379)
- Standard web ports (80, 443)

## Usage

Any container app can reference this environment:

```hcl
dependency "shared_env" {
  config_path = "../../shared-aca-env"
}

inputs = {
  container_app_environment_id = dependency.shared_env.outputs.container_app_environment_id
  resource_group_name          = dependency.shared_env.outputs.resource_group_name
  # ... other container config
}
```

## Deployment

```bash
./scripts/run.sh stacks/shared-aca-env/ apply
```

This takes ~11 minutes but only needs to be done once.
