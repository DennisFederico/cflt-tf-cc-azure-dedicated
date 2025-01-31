variable "resource_group" {
  description = "The name of the Azure Resource Group that the virtual network belongs to"
  type        = string
}

variable "region" {
  description = "The region of your VNet"
  type        = string
}

variable "vnet_name" {
  description = "The name of your VNet that you want to connect to Confluent Cloud Cluster"
  type        = string
}

variable "subnet_name_by_zone" {
  description = "A map of Zone to Subnet Name"
  type        = map(string)
}
