output "vm-name" {
  value = google_compute_instance.single_vm.name
}

output "vm-external-ip" {
  value = google_compute_instance.single_vm.network_interface.0.access_config.0.nat_ip
}

output "vm-internal-ip" {
  value = google_compute_instance.single_vm.network_interface.0.network_ip
}

output "docker-host" {
  value = "${google_compute_instance.single_vm.network_interface.0.access_config.0.nat_ip}:2376"
}

output "kubernetes-api" {
  value = "${google_compute_instance.single_vm.network_interface.0.access_config.0.nat_ip}:6443"
}
