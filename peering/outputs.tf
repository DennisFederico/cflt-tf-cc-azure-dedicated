output "vm_ips" {
  value = {
    hub_vm = {
      internal_ip = azurerm_network_interface.hub_nic.ip_configuration[0].private_ip_address
    }
    spoke1_vm = {
      internal_ip = azurerm_network_interface.spoke1_nic.ip_configuration[0].private_ip_address
    }
    spoke2_vm = {
      internal_ip = azurerm_network_interface.spoke2_nic.ip_configuration[0].private_ip_address
    }
  }
}