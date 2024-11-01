provider "google" {
  project = "primal-gear-436812-t0"
}

resource "google_compute_instance_template" "default" {
  name           = "apache-instance-template"
  machine_type   = "e2-medium"
  region         = "us-central1"

  disk {
    auto_delete  = true
    boot         = true
    source_image = "centos-cloud/centos-stream-9"
  }

  network_interface {
    network = "default"
    access_config {}
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    sudo systemctl start sshd
  EOF
}

resource "google_compute_instance_group_manager" "default" {
  name               = "apache-instance-group"
  version {
    instance_template = google_compute_instance_template.default.id
  }
  base_instance_name = "apache-instance"
  target_size        = 2
  zone               = "us-central1-a"

  named_port {
    name = "http"
    port = 80
  }
}

data "google_compute_instance_group" "default" {
  name = google_compute_instance_group_manager.default.name
  zone = "us-central1-a"
}

data "google_compute_instance" "instances" {
  count = length(tolist(data.google_compute_instance_group.default.instances))
  name  = split("/", tolist(data.google_compute_instance_group.default.instances)[count.index])[length(split("/", tolist(data.google_compute_instance_group.default.instances)[count.index])) - 1]
  zone  = "us-central1-a"
}

output "vm_ips" {
  value = [for instance in data.google_compute_instance.instances : instance.network_interface[0].access_config[0].nat_ip]
}
