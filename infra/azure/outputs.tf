output "vm-name" {
  value = azurerm_linux_virtual_machine.single_vm.name
}

output "vm-external-ip" {
  value = azurerm_public_ip.vm_public_ip.ip_address
}

output "vm-internal-ip" {
  value = azurerm_network_interface.nic.private_ip_address
}

output "docker-host" {
  value = "${azurerm_public_ip.vm_public_ip.ip_address}:2376"
}

output "kubernetes-api" {
  value = "${azurerm_public_ip.vm_public_ip.ip_address}:6443"
}
