provider "google" {
  project = "primal-gear-436812-t0"  # Update with your GCP project ID
  region  = "us-central1"
}

# Creating a firewall rule to allow HTTP traffic
resource "google_compute_firewall" "http-server" {
  name    = "http-server"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  # Allow traffic from everywhere to instances with an HTTP server tag
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server"]
}

# Creating the CentOS VM instance
resource "google_compute_instance" "centos_vm" {
  name         = "centos-vm1"
  machine_type = "e2-medium"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-stream-9"  # Correct image family
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }
  metadata = {
    ssh-keys = "centos:${file("/root/.ssh/id_rsa.pub")}"  # Update this path to your public key
  }

  tags = ["http-server"]

  # Using a provisioner to write the VM's public IP to the Ansible inventory file
  provisioner "local-exec" {
    command = "mkdir -p ansible && echo ${self.network_interface.0.access_config.0.nat_ip} > ansible/inventory.txt"
  }
}

output "vm_ip" {
  value = google_compute_instance.centos_vm.network_interface.0.access_config.0.nat_ip
}
