provider "google" {
  project = "primal-gear-436812-t0"
  region  = "us-central1"
}

resource "google_compute_instance" "centos_vm" {
  name         = "centos-vm2"
  machine_type = "e2-medium"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-stream-9"
    }
  }

  network_interface {
    network = "default"
    access_config {
    }
  }

  metadata = {
    ssh-keys = "centos:${file("/root/.ssh/id_rsa.pub")}"
  }

  tags = ["http-server"]

provisioner "local-exec" {
  command = <<EOT
    mkdir -p ansible && \
    echo "[web]" > ansible/inventory && \
    echo "${self.network_interface.0.access_config.0.nat_ip}" >> ansible/inventory
  EOT
}
}

output "vm_ip" {
  value = google_compute_instance.centos_vm.network_interface.0.access_config.0.nat_ip
}
