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

# O Resource Group continua sendo um recurso existente no Azure.
data "azurerm_resource_group" "lab" {
  name = "LinuxTeste"
}

# ============================================================
# REDE VIRTUAL E SUBNET — GERENCIADAS PELO TERRAFORM
# ============================================================

resource "azurerm_virtual_network" "lab" {
  name                = "LinuxTeste-vnet"
  location            = data.azurerm_resource_group.lab.location
  resource_group_name = data.azurerm_resource_group.lab.name
  address_space       = ["10.10.0.0/16"]
}

resource "azurerm_subnet" "default" {
  name                 = "default"
  resource_group_name  = data.azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.10.1.0/24"]
}

# ============================================================
# NETWORK SECURITY GROUP
# ============================================================

resource "azurerm_network_security_group" "vm" {
  name                = "LinuxTeste-TF-nsg"
  location            = data.azurerm_resource_group.lab.location
  resource_group_name = data.azurerm_resource_group.lab.name

  security_rule {
    name                       = "HTTP"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Mantida para administração quando a rede permitir SSH.
  # Na Fatec, o acesso SSH pode continuar bloqueado pela rede local.
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
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
  allocation_method   = "Static"
  sku                 = "Standard"
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
    subnet_id                     = azurerm_subnet.default.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm.id
  }
}

resource "azurerm_network_interface_security_group_association" "vm" {
  network_interface_id      = azurerm_network_interface.vm.id
  network_security_group_id = azurerm_network_security_group.vm.id
}

# ============================================================
# MÁQUINA VIRTUAL — DOCKER INSTALADO PELO CLOUD-INIT
# ============================================================

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "LinuxTeste-TF"
  resource_group_name = data.azurerm_resource_group.lab.name
  location            = data.azurerm_resource_group.lab.location
  size                = "Standard_B2ats_v2"

  admin_username                  = "azureuser"
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.vm.id
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDC6jsBFaxcs+eUbsbFdQMRdhuGQYV5g/BD/zhkiHE/g52mV1m2KjtODC47h3J0k+k9V0bewYA5+GNrvxngD4J3rbHhIRCHjNv4DbJqGljnSALeAUj16bxjZeL2nuJjgCjbIGUwNtH5G8y31vHZDCEJtM80a5KYWuy5ziM++UQi2DHTqErzsSYVtjII+OD4tZil3sa+hM5X1CN/ol9CytXxinvGfVKttLXnjY3LZQ1GxitYOoTujnGz5sPGtr7rxdlQJsR+OLJr7G66j2VV0PeaxDYL2JN2bWwdUUQbuFLlJH+ey0598vDnfYLKhYZZIBIOkphqsL99evX9ZgQExkhaDySJFwMZEHjcdBVbrlCsL9kcp/W/v2ecupPJewh/IMK60I0wAGuOgo+kRJF+r/LA1fcRjmZ58YsLx3wCC8cQtVuEriWY2/SZY1OvRXbep+cj+33Lj9X139mIp0MyFMRJURAI4kax8xLW4Hlf6AFKkd9Fk+S0W2qNrYkTv/zxy1U= imported-openssh-key"
  }

  # O Azure executa este script na primeira inicialização da VM.
  # A instalação pode continuar por alguns minutos após a VM ficar disponível.
  custom_data = base64encode(<<-CLOUDCONFIG
    #cloud-config
    package_update: true
    packages:
      - docker.io
    runcmd:
      - [systemctl, enable, --now, docker]
      - [usermod, -aG, docker, azureuser]
  CLOUDCONFIG
  )

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

output "rede_virtual" {
  value = azurerm_virtual_network.lab.name
}
