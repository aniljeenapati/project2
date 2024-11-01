provider "google" {
  project = "primal-gear-436812-t0"
  region  = "us-central1"
}

variable "instance_count" {
  default = 2
}

resource "google_compute_instance" "apache_instance" {
  count        = var.instance_count
  name         = "apache-instance-${count.index}"
  machine_type = "e2-medium"
  zone         = "us-central1-a"
  tags         = ["http-server"]

  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-stream-9"
    }
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

output "vm_ips" {
  value = [for instance in google_compute_instance.apache_instance : instance.network_interface[0].access_config[0].nat_ip]
}
