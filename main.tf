provider "google" {
  project = "primal-gear-436812-t0"
  region  = "us-central1"
}

resource "google_compute_instance" "centos_vm" {
  name         = "centosvm1"
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
    ssh-keys = "ansible:${file("/root/.ssh/id_rsa.pub")}"
  }
  
  tags = ["http-server"]
  provisioner "local-exec" {
    command = <<EOF
      mkdir -p ansible
      echo "[webserver]" > ansible/inventory
      echo "${self.network_interface.0.access_config.0.nat_ip} ansible_user=ansible ansible_ssh_private_key_file=/root/.ssh/id_rsa" >> ansible/inventory
    EOF
  }
}
resource "google_compute_firewall" "http-server" {
  name    = "http-server-firewall"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server"]
}
output "vm_ip" {
  value = google_compute_instance.centos_vm.network_interface.0.access_config.0.nat_ip
}
