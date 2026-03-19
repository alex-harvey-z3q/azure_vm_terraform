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

  vnet_name   = "vnet-personal-ansible-api"
  subnet_name = "snet-default"

  linux_vm_name        = "vm-personal-ansible-api"
  linux_admin_username = "azureuser"
  linux_vm_size        = "Standard_D2s_v3"

  windows_vm_name        = "vm-personal-windows"
  windows_admin_username = "azureuser"
  windows_vm_size        = "Standard_D2s_v3"

  address_space = ["10.10.0.0/16"]
  subnet_prefix = ["10.10.1.0/24"]

  ssh_private_key_path = "~/.ssh/id_ed25519"
}

variable "ssh_public_key" {
  type        = string
  description = "Your SSH public key contents"
}

variable "windows_admin_password" {
  type        = string
  sensitive   = true
  description = "Administrator password for the Windows VM"
}

resource "azurerm_resource_group" "this" {
  name     = local.resource_group_name
  location = local.location
}

resource "azurerm_virtual_network" "this" {
  name                = local.vnet_name
  address_space       = local.address_space
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_subnet" "this" {
  name                 = local.subnet_name
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = local.subnet_prefix
}

resource "azurerm_public_ip" "linux" {
  name                = "pip-personal-ansible-api"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "windows" {
  name                = "pip-personal-windows"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "this" {
  name                = "nsg-personal-ansible-api"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

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

  security_rule {
    name                       = "allow-rdp"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-winrm-https"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5986"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "linux" {
  name                = "nic-personal-ansible-api"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.this.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.linux.id
  }
}

resource "azurerm_network_interface" "windows" {
  name                = "nic-personal-windows"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.this.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.windows.id
  }
}

resource "azurerm_network_interface_security_group_association" "linux" {
  network_interface_id      = azurerm_network_interface.linux.id
  network_security_group_id = azurerm_network_security_group.this.id
}

resource "azurerm_network_interface_security_group_association" "windows" {
  network_interface_id      = azurerm_network_interface.windows.id
  network_security_group_id = azurerm_network_security_group.this.id
}

resource "azurerm_linux_virtual_machine" "linux" {
  name                = local.linux_vm_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  size                = local.linux_vm_size
  admin_username      = local.linux_admin_username

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.linux.id
  ]

  admin_ssh_key {
    username   = local.linux_admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    name                 = "osdisk-${local.linux_vm_name}"
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

resource "azurerm_windows_virtual_machine" "windows" {
  name                = local.windows_vm_name
  computer_name       = "winpoc01"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  size                = local.windows_vm_size
  admin_username      = local.windows_admin_username
  admin_password      = var.windows_admin_password

  network_interface_ids = [
    azurerm_network_interface.windows.id
  ]

  os_disk {
    name                 = "osdisk-${local.windows_vm_name}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "windows_winrm" {
  name                 = "enable-winrm"
  virtual_machine_id   = azurerm_windows_virtual_machine.windows.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Bypass -Command \"winrm quickconfig -q; Enable-PSRemoting -Force; Set-Item -Path WSMan:\\localhost\\Service\\Auth\\NTLM -Value $true; $cert = New-SelfSignedCertificate -DnsName 'winrm-selfsigned' -CertStoreLocation Cert:\\LocalMachine\\My; winrm create winrm/config/Listener?Address=*+Transport=HTTPS \\\"@{Hostname='winrm-selfsigned';CertificateThumbprint='$($cert.Thumbprint)'}\\\"; New-NetFirewallRule -DisplayName 'WinRM HTTPS' -Direction Inbound -Protocol TCP -LocalPort 5986 -Action Allow\""
  })
}

output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "linux_public_ip" {
  value = azurerm_public_ip.linux.ip_address
}

output "linux_private_ip" {
  value = azurerm_network_interface.linux.private_ip_address
}

output "ssh_command" {
  value = "ssh -i ${local.ssh_private_key_path} ${local.linux_admin_username}@${azurerm_public_ip.linux.ip_address}"
}

output "windows_public_ip" {
  value = azurerm_public_ip.windows.ip_address
}

output "windows_private_ip" {
  value = azurerm_network_interface.windows.private_ip_address
}

output "windows_admin_username" {
  value = local.windows_admin_username
}
