terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# ============================================================
# RECURSOS EXISTENTES
# ============================================================

data "azurerm_resource_group" "lab" {
  name = "LinuxTeste"
}

data "azurerm_virtual_network" "lab" {
  name                = "LinuxTeste-vnet"
  resource_group_name = data.azurerm_resource_group.lab.name
}

data "azurerm_subnet" "default" {
  name                 = "default"
  virtual_network_name = data.azurerm_virtual_network.lab.name
  resource_group_name  = data.azurerm_resource_group.lab.name
}

# ============================================================
# NETWORK SECURITY GROUP
# ============================================================

resource "azurerm_network_security_group" "vm" {
  name                = "LinuxTeste-TF-nsg"
  location            = data.azurerm_resource_group.lab.location
  resource_group_name = data.azurerm_resource_group.lab.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix     = "*"
    destination_address_prefix = "*"
  }
}

# ============================================================
# IP PÚBLICO
# ============================================================

resource "azurerm_public_ip" "vm" {
  name                = "LinuxTeste-TF-ip"
  location            = data.azurerm_resource_group.lab.location
  resource_group_name = data.azurerm_resource_group.lab.name

  allocation_method = "Static"
  sku               = "Standard"
}

# ============================================================
# INTERFACE DE REDE
# ============================================================

resource "azurerm_network_interface" "vm" {
  name                = "LinuxTeste-TF-nic"
  location            = data.azurerm_resource_group.lab.location
  resource_group_name = data.azurerm_resource_group.lab.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.default.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm.id
  }
}

# Associar o NSG à interface de rede
resource "azurerm_network_interface_security_group_association" "vm" {
  network_interface_id      = azurerm_network_interface.vm.id
  network_security_group_id = azurerm_network_security_group.vm.id
}

# ============================================================
# MÁQUINA VIRTUAL
# ============================================================

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "LinuxTeste-TF"
  resource_group_name = data.azurerm_resource_group.lab.name
  location            = data.azurerm_resource_group.lab.location
  size                = "Standard_B2ats_v2"

  admin_username = "azureuser"

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.vm.id
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCkw59WIxVKS7OaY3NIQRjxnncd93ojXzNezOSCLnbYFn3HueVBfYd+VXNpQTz51NSYzjyfxc/6yJ2wPbHPtYc4akHd+XppZzzMNvRUecWDquop8tvFkN3ucZVchC4vYozInYfTjkv89rsS5ELy9L8bShKpmWmkDKh3CkkgUFtB2TagqguYcPpqzhHbZ9Uuf4swKGnq+tc6cJ6M51RlrxYDVInaMuRHOOWfc39IXUP6VBU8dDc+1fKzZUUohlFqHuUhFuM6WshNzoouIvrU9U8dy5iKQYk/B1Z7BwwZyh2QKjWhI/PErdh2620khrdTzOdCPfvc561STsyjhRM5DYpFaBJNhC7xQQe4toyRQfhz61yeyRl10L15D5qabUcwyaQhteKI3G7ZJdji5Msv2I7tAgBAGobHgOz+bNJjV+1jVRKyYUO5902wakheQNNlxdkRBow4+nvFFpxyUlUM5MnsccFWpdSKec/J+8+5+CidM640JyMis2so3YFyHfN8kNE= imported-openssh-key"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

# ============================================================
# OUTPUTS
# ============================================================

output "nome_vm" {
  value = azurerm_linux_virtual_machine.vm.name
}

output "ip_publico" {
  value = azurerm_public_ip.vm.ip_address
}

output "tamanho_vm" {
  value = azurerm_linux_virtual_machine.vm.size
}