terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  address_space       = var.address_space
  location            = var.location
  resource_group_name = var.resource_group_name
}

# Subnet
resource "azurerm_subnet" "subnet" {
  name                 = var.subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_address_prefix]

  dynamic "delegation" {
    for_each = var.subnet_delegation != null ? [var.subnet_delegation] : []
    content {
      name = delegation.value.name

      service_delegation {
        name    = delegation.value.service
        actions = delegation.value.actions
      }
    }
  }
}

# Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                = var.nsg_name
  location            = var.location
  resource_group_name = var.resource_group_name

  # Default HTTP/HTTPS rules
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

  # Custom additional ports
  dynamic "security_rule" {
    for_each = var.additional_ports
    iterator = port
    content {
      name                       = "Allow_${port.key}"
      priority                   = 200 + index(keys(var.additional_ports), port.key)
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = port.value.protocol
      source_port_range          = "*"
      destination_port_range     = tostring(port.value.port)
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
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}
