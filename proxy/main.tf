terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.15.0"
    }
  }
}

provider "azurerm" {
  features {
    # See. https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs#authenticating-to-azure
    #
    # Assuming a Service Principal with a Client Secret authentication, expose the following environment variables
    # use ARM_CLIENT_ID env var
    # use ARM_CLIENT_SECRET env var
    # use ARM_TENANT_ID env var
    # use ARM_SUBSCRIPTION_ID env var
  }
}

# Create a new resource group if needed
data "azurerm_resource_group" "hub_resource_group" {
  name = var.hub_resource_group_name
}

# Create a new virtual network
data "azurerm_virtual_network" "hub_vnet" {
  name                = var.hub_vnet_name
  resource_group_name = data.azurerm_resource_group.hub_resource_group.name
}

data "azurerm_subnet" "hub_default_subnet" {
  name                 = "default"
  virtual_network_name = data.azurerm_virtual_network.hub_vnet.name
  resource_group_name  = data.azurerm_resource_group.hub_resource_group.name
}

resource "azurerm_linux_virtual_machine" "nginx_vm" {
  name                = "nginx-vm"
  resource_group_name = data.azurerm_resource_group.hub_resource_group.name
  location            = data.azurerm_resource_group.hub_resource_group.location

  size           = "Standard_B1ls"
  admin_username = "dfederico"

  network_interface_ids = [azurerm_network_interface.nginx_vm_nic.id]

  admin_ssh_key {
    username   = "dfederico"
    public_key = file("~/.ssh/id_rsa_jump.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Debian"
    offer     = "Debian-11"
    sku       = "11-backports-gen2"
    version   = "latest"
  }

  custom_data = filebase64("${path.module}/nginx-install.yml")
}

resource "azurerm_public_ip" "nginx_public_nic" {
  name                = "nginx-public-ip"
  resource_group_name = data.azurerm_resource_group.hub_resource_group.name
  location            = data.azurerm_resource_group.hub_resource_group.location
  sku                 = "Basic"
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "nginx_vm_nic" {
  name                = "nginx-nic"
  resource_group_name = data.azurerm_resource_group.hub_resource_group.name
  location            = data.azurerm_resource_group.hub_resource_group.location

  ip_configuration {
    name                          = "nginx-ip"
    subnet_id                     = data.azurerm_subnet.hub_default_subnet.id
    private_ip_address_allocation = "Dynamic"

    public_ip_address_id = azurerm_public_ip.nginx_public_nic.id
  }  
}

resource "azurerm_network_security_group" "nginx_vm_nsg" {
  name                = "nginx-nsg"
  resource_group_name = data.azurerm_resource_group.hub_resource_group.name
  location            = data.azurerm_resource_group.hub_resource_group.location
}

resource "azurerm_network_security_rule" "allow_nginx" {
  network_security_group_name = azurerm_network_security_group.nginx_vm_nsg.name
  resource_group_name         = data.azurerm_resource_group.hub_resource_group.name
  name                        = "allow-nginx"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = [var.external_ip, "10.0.0.0/8", "20.0.0.0/8", "30.0.0.0/8"]
  destination_address_prefix  = "*"
}

resource "azurerm_network_interface_security_group_association" "nginx_nic_nsg" {
  network_interface_id      = azurerm_network_interface.nginx_vm_nic.id
  network_security_group_id = azurerm_network_security_group.nginx_vm_nsg.id
}
