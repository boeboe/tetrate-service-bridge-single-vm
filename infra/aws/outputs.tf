output "vm-name" {
  value = aws_instance.single_vm.arn
}

output "vm-external-ip" {
  value = aws_instance.single_vm.public_ip
}

output "vm-external-dns" {
  value = aws_instance.single_vm.public_dns
}

output "vm-internal-ip" {
  value = aws_instance.single_vm.private_ip
}

output "vm-internal-dns" {
  value = aws_instance.single_vm.private_dns
}

output "docker-host" {
  value = "${aws_instance.single_vm.public_ip}:2376"
}

output "kubernetes-api" {
  value = "${aws_instance.single_vm.public_ip}:6443"
}

output "ssh-commmand" {
  value = "ssh ${var.ssh.user}@${aws_instance.single_vm.public_ip}"
}
