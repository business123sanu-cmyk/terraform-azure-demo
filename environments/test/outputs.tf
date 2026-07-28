output "vm_public_ip" {
  value = azurerm_public_ip.pip[*].ip_address
}

output "vm_name" {
  value = azurerm_linux_virtual_machine.vm[*].name
}
