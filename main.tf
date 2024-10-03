provider "google" {
  project = "primal-gear-436812-t0"  # Replace with your project ID
  region  = "us-central1"
}

resource "google_compute_instance" "centos_vm" {
  name         = "centos-vm"
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
    ssh-keys = "centos:${file("/root/.ssh/id_rsa.pub")}"  # Path to your SSH public key
  }

  tags = ["http-server"]
}

# Output the public IP address of the VM
output "vm_ip" {
  value = google_compute_instance.centos_vm.network_interface.0.access_config.0.nat_ip
}

# Local-exec to write the IP address to the Ansible inventory file
resource "null_resource" "update_inventory" {
  provisioner "local-exec" {
    command = <<EOT
      echo 'all:
  hosts:
    web:
      ansible_host: ${google_compute_instance.centos_vm.network_interface.0.access_config.0.nat_ip}
      ansible_user: centos
      ansible_ssh_private_key_file: /root/.ssh/id_rsa
' > /var/lib/jenkins/workspace/terra-ans/inventory.gcp.yml
    EOT
  }

  # Ensure the VM creation happens before the inventory update
  depends_on = [google_compute_instance.centos_vm]
}
