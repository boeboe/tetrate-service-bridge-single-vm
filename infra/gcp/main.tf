resource "random_string" "random_prefix" {
  length  = 4
  special = false
  lower   = true
  upper   = false
  numeric = false
}

resource "google_project" "tsb_single_vm" {
  name            = "${var.project_name}-${random_string.random_prefix.result}"
  project_id      = "${var.project_name}-${random_string.random_prefix.result}"
  org_id          = var.org_id
  billing_account = var.billing_account
  tags          = var.tags
}

resource "google_project_service" "compute" {
  project = google_project.tsb_single_vm.project_id
  service = "compute.googleapis.com"

}

resource "google_project_service" "containerregistry" {
  project = google_project.tsb_single_vm.project_id
  service = "containerregistry.googleapis.com"
}

resource "google_project_service" "dns" {
  project = google_project.tsb_single_vm.project_id
  service = "dns.googleapis.com"
}

resource "time_sleep" "wait_60_seconds" {
  depends_on = [
    google_project_service.compute,
    google_project_service.containerregistry,
    google_project_service.dns
  ]
  create_duration = "60s"
}

resource "google_compute_instance" "single_vm" {
  name         = var.vm_name
  machine_type = var.vm_machine_type
  zone         = var.zone
  project      = google_project.tsb_single_vm.project_id

  boot_disk {
    initialize_params {
      image = "ubuntu-os-pro-cloud/ubuntu-pro-2204-lts"
    }
  }

  network_interface {
    network = "default"

    access_config {
      // This will assign a public IP to the VM
    }
  }

  metadata = {
    ssh-keys = "${var.ssh.user}:${file("${var.ssh.key}")}"
    user-data = templatefile("${path.module}/templates/docker-cloud-init.tpl", {
      hostname    = var.vm_name
      docker_port = var.docker_port
      ssh_user    = var.ssh.user
    })
  }

  tags = ["http-server", "https-server", "docker-daemon", "kubernetes-api"]

  depends_on = [
    time_sleep.wait_60_seconds
  ]
}

resource "google_compute_firewall" "web" {
  name    = "default-allow-http-https"
  network = "default"
  project = google_project.tsb_single_vm.project_id

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server", "https-server"]
}

resource "google_compute_firewall" "docker" {
  name    = "allow-docker"
  network = "default"
  project = google_project.tsb_single_vm.project_id

  allow {
    protocol = "tcp"
    ports    = ["2376"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["docker-daemon"]
}

resource "google_compute_firewall" "kubernetes_api" {
  name    = "allow-kubernetes-api"
  network = "default"
  project = google_project.tsb_single_vm.project_id

  allow {
    protocol = "tcp"
    ports    = ["6443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["kubernetes-api"]
}

resource "null_resource" "wait_for_docker_ready" {
  triggers = {
    instance_id = google_compute_instance.single_vm.id
    always_run  = timestamp()
  }
  provisioner "local-exec" {
    command     = <<EOT
      count=0
      max_count=30
      until echo > /dev/tcp/${google_compute_instance.single_vm.network_interface[0].access_config[0].nat_ip}/${var.docker_port} || [ $count -eq $max_count ]; do
        echo "Waiting for port ${var.docker_port}... (count: $count)"
        sleep 10
        count=$((count+1))
      done
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [google_compute_instance.single_vm]
}
