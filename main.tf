provider "google" {
  project = "primal-gear-436812-t0"
  region  = "us-central1"
}

resource "google_compute_instance" "centos_vm" {
  name         = "centos-vm3"
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

  // Local-exec provisioner to create the inventory.gcp.yml file
  provisioner "local-exec" {
    command = <<EOT
      mkdir -p ansible && \
      echo "---" > ansible/inventory.gcp.yml && \
      echo "plugin: gcp_compute" >> ansible/inventory.gcp.yml && \
      echo "projects:" >> ansible/inventory.gcp.yml && \
      echo "  - primal-gear-436812-t0" >> ansible/inventory.gcp.yml && \
      echo "zones:" >> ansible/inventory.gcp.yml && \
      echo "  - us-central1-a" >> ansible/inventory.gcp.yml && \
      echo "auth_kind: serviceaccount" >> ansible/inventory.gcp.yml && \
      echo "service_account_file: /path/to/your/service-account.json" >> ansible/inventory.gcp.yml && \
      echo "hostnames:" >> ansible/inventory.gcp.yml && \
      echo "  - name" >> ansible/inventory.gcp.yml && \
      echo "filters:" >> ansible/inventory.gcp.yml && \
      echo "  - status = RUNNING" >> ansible/inventory.gcp.yml
    EOT
  }
}

output "vm_ip" {
  value = google_compute_instance.centos_vm.network_interface.0.access_config.0.nat_ip
}
