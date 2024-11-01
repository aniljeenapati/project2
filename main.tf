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

# Create a null resource to fetch the IPs after the instances are created
resource "null_resource" "get_instance_ips" {
  provisioner "local-exec" {
    command = <<EOT
      # Get the instance group instances and their IPs
      gcloud compute instance-groups list-instances ${google_compute_instance_group_manager.default.instance_group} \
      --zone ${google_compute_instance_group_manager.default.zone} \
      --format="get(instance,networkInterfaces[0].accessConfigs[0].natIP)" > instance_ips.txt

      # Generate the Ansible inventory from the instance IPs
      echo "all:" > inventory.gcp.yml
      echo "  children:" >> inventory.gcp.yml
      echo "    web:" >> inventory.gcp.yml
      echo "      hosts:" >> inventory.gcp.yml
      while read ip; do
        echo "        web_ansible-\$ip:" >> inventory.gcp.yml
        echo "          ansible_host: \$ip" >> inventory.gcp.yml
        echo "          ansible_user: centos" >> inventory.gcp.yml
        echo "          ansible_ssh_private_key_file: /var/lib/jenkins/.ssh/id_rsa" >> inventory.gcp.yml
      done < instance_ips.txt
    EOT
  }

  depends_on = [
    google_compute_instance_group_manager.default
  ]
}
