variable "hub_resource_group_name" {
  description = "The name of the resource group for the new virtual network"
}

variable "hub_vnet_name" {
  description = "The name of the new virtual network"
}

variable "external_ip" {
  description = "An external IP for the optional firewall rules"
}