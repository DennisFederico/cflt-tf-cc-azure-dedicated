output "nginx_public_ip" {
  value = azurerm_public_ip.nginx_public_nic.ip_address
}