terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

locals {
  location            = "australiasoutheast"
  resource_group_name = "rg-personal-ansible-api"

  vm_name        = "vm-personal-ansible-api"
  admin_username = "azureuser"

  ssh_public_key = var.ssh_public_key
}

variable "ssh_public_key" {
  type        = string
  description = "Your SSH public key contents"
}

resource "azurerm_resource_group" "this" {
  name     = local.resource_group_name
  location = local.location
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-personal-ansible-api"
  address_space       = ["10.10.0.0/16"]
  location            = local.location
  resource_group_name = local.resource_group_name
}

resource "azurerm_subnet" "this" {
  name                 = "snet-default"
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_public_ip" "this" {
  name                = "pip-personal-ansible-api"
  location            = local.location
  resource_group_name = local.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "this" {
  name                = "nsg-personal-ansible-api"
  location            = local.location
  resource_group_name = local.resource_group_name

  security_rule {
    name                       = "allow-ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-flask-api"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "this" {
  name                = "nic-personal-ansible-api"
  location            = local.location
  resource_group_name = local.resource_group_name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.this.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.this.id
  }
}

resource "azurerm_network_interface_security_group_association" "this" {
  network_interface_id      = azurerm_network_interface.this.id
  network_security_group_id = azurerm_network_security_group.this.id
}

resource "azurerm_linux_virtual_machine" "this" {
  name                = local.vm_name
  resource_group_name = local.resource_group_name
  location            = local.location
  size                = "Standard_D2s_v3"
  admin_username      = local.admin_username

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.this.id
  ]

  admin_ssh_key {
    username   = local.admin_username
    public_key = local.ssh_public_key
  }

  os_disk {
    name                 = "osdisk-${local.vm_name}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "public_ip" {
  value = azurerm_public_ip.this.ip_address
}

output "ssh_command" {
  value = "ssh ${local.admin_username}@${azurerm_public_ip.this.ip_address}"
}
