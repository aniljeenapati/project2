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

  metadata = {
    ssh-keys = "centos:${file("/var/lib/jenkins/.ssh/id_rsa.pub")}"
    }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    sudo systemctl start sshd
  EOF
  metadata = {
    ssh-keys = "centos:${file("/var/lib/jenkins/.ssh/id_rsa.pub")}"
  }

  tags = ["http-server"]
}

output "vm_ips" {
  value = [for instance in google_compute_instance.centos_vm : instance.network_interface[0].access_config[0].nat_ip]
}

resource "null_resource" "generate_inventory" {
  provisioner "local-exec" {
    command = <<EOT
      echo 'all:' > /var/lib/jenkins/workspace/loadbalancer/inventory.gcp.yml
      echo '  children:' >> /var/lib/jenkins/workspace/loadbalancer/inventory.gcp.yml
      echo '    web:' >> /var/lib/jenkins/workspace/loadbalancer/inventory.gcp.yml
      echo '      hosts:' >> /var/lib/jenkins/workspace/loadbalancer/inventory.gcp.yml
      for i in $(seq 0 2); do
        INSTANCE_IP=$(terraform output -json vm_ips | jq -r ".[$i]")
        echo "        web_ansible-$((i + 1)):" >> /var/lib/jenkins/workspace/loadbalancer/inventory.gcp.yml
        echo "          ansible_host: \$INSTANCE_IP" >> /var/lib/jenkins/workspace/loadbalancer/inventory.gcp.yml
        echo "          ansible_user: centos" >> /var/lib/jenkins/workspace/loadbalancer/inventory.gcp.yml
        echo "          ansible_ssh_private_key_file: /var/lib/jenkins/.ssh/id_rsa" >> /var/lib/jenkins/workspace/loadbalancer/inventory.gcp.yml
      done
    EOT
   }
 }
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
