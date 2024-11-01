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

# Data block to get the instance group instances
data "google_compute_instance_group" "default" {
  name = google_compute_instance_group_manager.default.instance_group
  zone = "us-central1-a"
}

data "google_compute_instance" "instances" {
  count = length(data.google_compute_instance_group.default.instances)
  name  = data.google_compute_instance_group.default.instances[count.index].name
  zone  = "us-central1-a"
}

# Output the VM IPs
output "vm_ips" {
  value = [for instance in data.google_compute_instance.instances : instance.network_interface[0].access_config[0].nat_ip]
}

# Resource to generate Ansible inventory
resource "null_resource" "generate_ansible_inventory" {
  provisioner "local-exec" {
    command = <<EOT
      # Get the VM IPs and generate Ansible inventory
      echo "all:" > inventory.gcp.yml
      echo "  children:" >> inventory.gcp.yml
      echo "    web:" >> inventory.gcp.yml
      echo "      hosts:" >> inventory.gcp.yml
      for ip in $(terraform output -json vm_ips | jq -r '.[]'); do
        echo "        web_ansible-\${ip}:" >> inventory.gcp.yml
        echo "          ansible_host: \${ip}" >> inventory.gcp.yml
        echo "          ansible_user: centos" >> inventory.gcp.yml
        echo "          ansible_ssh_private_key_file: /var/lib/jenkins/.ssh/id_rsa" >> inventory.gcp.yml
      done
    EOT
  }

  depends_on = [
    google_compute_instance_group_manager.default
  ]
}
