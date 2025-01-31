variable "hub_resource_group_name" {
  description = "The resource group of the existing virtual network to peer with"
}

variable "spoke1_resource_group_name" {
  description = "The name of the resource group for the new virtual network"
}

variable "spoke2_resource_group_name" {
  description = "The name of the resource group for the new virtual network"
}

variable "hub_vnet_name" {
  description = "The name of the existing virtual network to peer with"
}

variable "spoke1_vnet_name" {
  description = "The name of the new virtual network"
}

variable "spoke2_vnet_name" {
  description = "The name of the new virtual network"
}

variable "spoke1_vnet_cidr" {
  description = "The CIDR of the new vNet (should not overlap with the exiting vNet to peer with)"
}

variable "spoke2_vnet_cidr" {
  description = "The CIDR of the subnet to create on the new vNet"
}

variable "spoke1_default_subnet_cidr" {
  description = "The CIDR of the new vNet (should not overlap with the exiting vNet to peer with)"
}

variable "spoke2_default_subnet_cidr" {
  description = "The CIDR of the subnet to create on the new vNet"
}

variable "hub_private_dns_domain" {
  description = "The name of the Private DNS on the Hub vNet created when setting up the cluster"
}

variable "external_ip" {
  description = "An external IP for the optional firewall rules"
}
