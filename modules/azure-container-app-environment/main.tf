terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

resource "azurerm_resource_group" "rg" {
  name     = var.name
  location = var.location
  tags = {
    name = var.name
  }
}

# Create VNET and subnet for Container App Environment if external TCP is needed
resource "azurerm_virtual_network" "vnet" {
  count               = var.create_vnet ? 1 : 0
  name                = var.name
  address_space       = var.vnet_address_space
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  count                = var.create_vnet ? 1 : 0
  name                 = var.name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet[0].name
  address_prefixes     = [var.subnet_address_prefix]
}

# Network Security Group for the subnet
resource "azurerm_network_security_group" "nsg" {
  count               = var.create_vnet ? 1 : 0
  name                = var.name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # Allow common ports for Container Apps
  security_rule {
    name                       = "AllowHTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow custom ports (configurable)
  dynamic "security_rule" {
    for_each = var.allowed_inbound_ports
    content {
      name                       = "Allow${security_rule.value.name}"
      priority                   = 200 + security_rule.key
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = security_rule.value.protocol
      source_port_range          = "*"
      destination_port_range     = security_rule.value.port
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }

  # Allow Container Apps internal communication
  security_rule {
    name                       = "AllowContainerAppsInternal"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.subnet_address_prefix
    destination_address_prefix = var.subnet_address_prefix
  }

  # Allow outbound internet access
  security_rule {
    name                       = "AllowOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Associate NSG with subnet
resource "azurerm_subnet_network_security_group_association" "nsga" {
  count                     = var.create_vnet ? 1 : 0
  subnet_id                 = azurerm_subnet.subnet[0].id
  network_security_group_id = azurerm_network_security_group.nsg[0].id
}

resource "azurerm_container_app_environment" "env" {
  name                = var.name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # Use custom VNET if created
  infrastructure_subnet_id = var.create_vnet ? azurerm_subnet.subnet[0].id : null

  # Ensure all network resources are ready before creating the environment
  depends_on = [
    azurerm_virtual_network.vnet,
    azurerm_subnet.subnet,
    azurerm_subnet_network_security_group_association.nsga
  ]
}
