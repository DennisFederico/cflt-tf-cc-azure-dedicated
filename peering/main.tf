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

##### RESOURCE GROUPS
data "azurerm_resource_group" "hub_resource_group" {
  name = var.hub_resource_group_name
}

# Create a new resource group if needed
data "azurerm_resource_group" "spoke1_resource_group" {
  name = var.spoke1_resource_group_name
}

# Create a new resource group if needed
data "azurerm_resource_group" "spoke2_resource_group" {
  name = var.spoke2_resource_group_name
}

##### VIRTUAL NETWORKS
# Retrieve the existing virtual network
data "azurerm_virtual_network" "hub_vnet" {
  name                = var.hub_vnet_name
  resource_group_name = var.hub_resource_group_name
}

resource "azurerm_virtual_network" "spoke1_vnet" {
  name                = var.spoke1_vnet_name
  resource_group_name = data.azurerm_resource_group.spoke1_resource_group.name
  location            = data.azurerm_resource_group.spoke1_resource_group.location
  address_space       = [var.spoke1_vnet_cidr]

  subnet {
    name             = "default"
    address_prefixes = [var.spoke1_default_subnet_cidr]
  }
}

resource "azurerm_virtual_network" "spoke2_vnet" {
  name                = var.spoke2_vnet_name
  resource_group_name = data.azurerm_resource_group.spoke2_resource_group.name
  location            = data.azurerm_resource_group.spoke2_resource_group.location
  address_space       = [var.spoke2_vnet_cidr]

  subnet {
    name             = "default"
    address_prefixes = [var.spoke2_default_subnet_cidr]
  }
}

# Create peering from new vNet to existing vNet
resource "azurerm_virtual_network_peering" "spoke1_to_hub_peering" {
  name                         = "${var.spoke1_vnet_name}-to-${var.hub_vnet_name}-peering"
  resource_group_name          = data.azurerm_resource_group.spoke1_resource_group.name
  virtual_network_name         = azurerm_virtual_network.spoke1_vnet.name
  remote_virtual_network_id    = data.azurerm_virtual_network.hub_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  use_remote_gateways          = false
}

# Create peering from existing vNet to new vNet
resource "azurerm_virtual_network_peering" "hub_to_spoke1_peering" {
  name                         = "${var.hub_vnet_name}-to-${var.spoke1_vnet_name}-peering"
  resource_group_name          = data.azurerm_resource_group.hub_resource_group.name
  virtual_network_name         = data.azurerm_virtual_network.hub_vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke1_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "spoke2_to_hub_peering" {
  name                         = "${var.spoke2_vnet_name}-to-${var.hub_vnet_name}-peering"
  resource_group_name          = data.azurerm_resource_group.spoke2_resource_group.name
  virtual_network_name         = azurerm_virtual_network.spoke2_vnet.name
  remote_virtual_network_id    = data.azurerm_virtual_network.hub_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  use_remote_gateways          = false
}

# Create peering from existing vNet to new vNet
resource "azurerm_virtual_network_peering" "hub_to_spoke2_peering" {
  name                         = "${var.hub_vnet_name}-to-${var.spoke2_vnet_name}-peering"
  resource_group_name          = data.azurerm_resource_group.hub_resource_group.name
  virtual_network_name         = data.azurerm_virtual_network.hub_vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke2_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  use_remote_gateways          = false
}


###################################################################
###################################################################
##### UPDATE Private DNS Hosted Zone Created with the Cluster #####
###################################################################
###################################################################

data "azurerm_private_dns_zone" "hub_private_dns" {
  // The name is found in the cluster script
  // confluent_private_link_attachment.main.dns_domain
  name                = var.hub_private_dns_domain
  resource_group_name = data.azurerm_resource_group.hub_resource_group.name
}

## LINK TO SPOKE 1 vNET
resource "azurerm_private_dns_zone_virtual_network_link" "spoke1_dns_link" {
  name                  = azurerm_virtual_network.spoke1_vnet.name
  private_dns_zone_name = data.azurerm_private_dns_zone.hub_private_dns.name
  resource_group_name   = data.azurerm_resource_group.hub_resource_group.name
  virtual_network_id    = azurerm_virtual_network.spoke1_vnet.id

  # Optional: Set to `true` to enable auto-registration of DNS records
  registration_enabled = true
}

## LINK TO SPOKE 2 vNET
resource "azurerm_private_dns_zone_virtual_network_link" "spoke2_dns_link" {
  name                  = azurerm_virtual_network.spoke2_vnet.name
  private_dns_zone_name = data.azurerm_private_dns_zone.hub_private_dns.name
  resource_group_name   = data.azurerm_resource_group.hub_resource_group.name
  virtual_network_id    = azurerm_virtual_network.spoke2_vnet.id

  # Optional: Set to `true` to enable auto-registration of DNS records
  registration_enabled = true
}




##################################################################
##################################################################
### (OPTIONAL) Creating a VM on each vNet to test connectivity ###
##################################################################
##################################################################

#### VM on HUB vNet ####
# Create a VM in the existing virtual network
resource "azurerm_linux_virtual_machine" "hub_vm" {
  name                = "hubVM"
  resource_group_name = data.azurerm_resource_group.hub_resource_group.name
  location            = data.azurerm_resource_group.hub_resource_group.location
  size                = "Standard_DS1_v2"
  admin_username      = "dfederico"
  network_interface_ids = [
    azurerm_network_interface.hub_nic.id,
  ]
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
}

data "azurerm_subnet" "hub_default_subnet" {
  name                 = "default"
  virtual_network_name = data.azurerm_virtual_network.hub_vnet.name
  resource_group_name  = data.azurerm_resource_group.hub_resource_group.name
}

# Create a network interface for the existing VM
resource "azurerm_network_interface" "hub_nic" {
  name                = "hubVM-nic"
  resource_group_name = data.azurerm_resource_group.hub_resource_group.name
  location            = data.azurerm_resource_group.hub_resource_group.location

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = data.azurerm_subnet.hub_default_subnet.id
    private_ip_address_allocation = "Dynamic"

    # (OPTIONAL) Associate the public IP
    # public_ip_address_id = azurerm_public_ip.hub_vm_public_ip.id
  }
}

# (OPTIONAL) Create a public IP for the HUB VM
# resource "azurerm_public_ip" "hub_vm_public_ip" {
#   name                = "hubVM-public-ip"
#   resource_group_name = data.azurerm_resource_group.existing_resource_group.name
#   location            = data.azurerm_resource_group.existing_resource_group.location
#   sky                 = "Basic"
#   allocation_method   = "Dynamic"
# }


#### VM on SPOKE vNet ####
# Create a VM in the new virtual network
resource "azurerm_linux_virtual_machine" "spoke1_vm" {
  name                = "spoke1VM"
  resource_group_name = data.azurerm_resource_group.spoke1_resource_group.name
  location            = data.azurerm_resource_group.spoke1_resource_group.location
  size                = "Standard_DS1_v2"
  admin_username      = "dfederico"

  network_interface_ids = [
    azurerm_network_interface.spoke1_nic.id,
  ]

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
}

data "azurerm_subnet" "spoke1_default_subnet" {
  name                 = "default"
  virtual_network_name = azurerm_virtual_network.spoke1_vnet.name
  resource_group_name  = data.azurerm_resource_group.spoke1_resource_group.name

  depends_on = [azurerm_virtual_network.spoke1_vnet]
}

# # (OPTIONAL) Create a public IP for the spoke VM
# resource "azurerm_public_ip" "spoke1_vm_public_ip" {
#   name                = "spoke1VM-public-ip"
#   resource_group_name = data.azurerm_resource_group.spoke1_resource_group.name
#   location            = data.azurerm_resource_group.spoke1_resource_group.location
#   sky                 = "Basic"
#   allocation_method   = "Dynamic"
# }

# Create a network interface for the SPOKE VM
resource "azurerm_network_interface" "spoke1_nic" {
  name                = "spokeVM-nic"
  resource_group_name = data.azurerm_resource_group.spoke1_resource_group.name
  location            = data.azurerm_resource_group.spoke1_resource_group.location

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = data.azurerm_subnet.spoke1_default_subnet.id
    private_ip_address_allocation = "Dynamic"

    # # (OPTIONAL) Associate the public IP
    # public_ip_address_id = azurerm_public_ip.spoke1_vm_public_ip.id
  }
}

#### VM on SPOKE2 vNet ####
# Create a VM in the existing virtual network (Spoke2)
resource "azurerm_linux_virtual_machine" "spoke2_vm" {
  name                = "spoke2VM"
  resource_group_name = data.azurerm_resource_group.spoke2_resource_group.name
  location            = data.azurerm_resource_group.spoke2_resource_group.location
  size                = "Standard_DS1_v2"
  admin_username      = "dfederico"
  network_interface_ids = [
    azurerm_network_interface.spoke2_nic.id,
  ]
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
}

data "azurerm_subnet" "spoke2_default_subnet" {
  name                 = "default"
  virtual_network_name = azurerm_virtual_network.spoke2_vnet.name
  resource_group_name  = data.azurerm_resource_group.spoke2_resource_group.name

  depends_on = [azurerm_virtual_network.spoke2_vnet]
}

# Create a network interface for the existing VM
resource "azurerm_network_interface" "spoke2_nic" {
  name                = "spoke2VM-nic"
  resource_group_name = data.azurerm_resource_group.spoke2_resource_group.name
  location            = data.azurerm_resource_group.spoke2_resource_group.location

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = data.azurerm_subnet.spoke2_default_subnet.id
    private_ip_address_allocation = "Dynamic"

    # (OPTIONAL) Associate the public IP
    # public_ip_address_id = azurerm_public_ip.spoke2_vm_public_ip.id
  }
}

# # (OPTIONAL) Create a public IP for the spoke VM
# resource "azurerm_public_ip" "spoke2_vm_public_ip" {
#   name                = "spoke2VM-public-ip"
#   resource_group_name = data.azurerm_resource_group.spoke2_resource_group.name
#   location            = data.azurerm_resource_group.spoke2_resource_group.location
#   sky                 = "Basic"
#   allocation_method   = "Dynamic"
# }



###################################################################
###################################################################
### (OPTIONAL) Firewall for external SSH - Use only for testing ###
###################################################################
###################################################################

resource "azurerm_network_security_group" "hub_vm_nsg" {
  name                = "hub-nsg"
  resource_group_name = data.azurerm_resource_group.hub_resource_group.name
  location            = data.azurerm_resource_group.hub_resource_group.location
}

resource "azurerm_network_security_rule" "allow_ssh_hub" {
  network_security_group_name = azurerm_network_security_group.hub_vm_nsg.name
  resource_group_name         = data.azurerm_resource_group.hub_resource_group.name
  name                        = "allow-ssh"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefixes     = [var.external_ip, "10.0.0.0/8", var.spoke1_vnet_cidr, var.spoke2_vnet_cidr]
  destination_address_prefix  = "*"
}

resource "azurerm_network_security_rule" "allow_ping_hub" {
  network_security_group_name = azurerm_network_security_group.hub_vm_nsg.name
  resource_group_name         = data.azurerm_resource_group.hub_resource_group.name
  name                        = "allow-Ping"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Icmp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
}

resource "azurerm_network_security_group" "spoke1_vm_nsg" {
  name                = "spoke1-nsg"
  resource_group_name = data.azurerm_resource_group.spoke1_resource_group.name
  location            = data.azurerm_resource_group.spoke1_resource_group.location
}

resource "azurerm_network_security_rule" "allow_ssh_spoke1" {
  network_security_group_name = azurerm_network_security_group.spoke1_vm_nsg.name
  resource_group_name         = data.azurerm_resource_group.spoke1_resource_group.name
  name                        = "allow-ssh"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefixes     = [var.external_ip, "10.0.0.0/8"]
  destination_address_prefix  = "*"
}

resource "azurerm_network_security_rule" "allow_ping_spoke1" {
  network_security_group_name = azurerm_network_security_group.spoke1_vm_nsg.name
  resource_group_name         = data.azurerm_resource_group.spoke1_resource_group.name
  name                        = "allow-Ping"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Icmp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
}

resource "azurerm_network_security_group" "spoke2_vm_nsg" {
  name                = "spoke2-nsg"
  resource_group_name = data.azurerm_resource_group.spoke2_resource_group.name
  location            = data.azurerm_resource_group.spoke2_resource_group.location
}

resource "azurerm_network_security_rule" "allow_ssh_spoke2" {
  network_security_group_name = azurerm_network_security_group.spoke2_vm_nsg.name
  resource_group_name         = data.azurerm_resource_group.spoke2_resource_group.name
  name                        = "allow-ssh"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefixes     = [var.external_ip, "10.0.0.0/8"]
  destination_address_prefix  = "*"
}

resource "azurerm_network_security_rule" "allow_ping_spoke2" {
  network_security_group_name = azurerm_network_security_group.spoke2_vm_nsg.name
  resource_group_name         = data.azurerm_resource_group.spoke2_resource_group.name
  name                        = "allow-Ping"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Icmp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
}

