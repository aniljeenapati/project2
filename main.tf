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

resource "google_compute_backend_service" "default" {
  name          = "apache-backend-service"
  backend {
    group = google_compute_instance_group_manager.default.instance_group
  }
  health_checks = [google_compute_http_health_check.default.id]
  port_name     = "http"
  protocol      = "HTTP"
  timeout_sec   = 30
  load_balancing_scheme = "EXTERNAL"
}

resource "google_compute_http_health_check" "default" {
  name                    = "apache-health-check"
  request_path            = "/"
  port                    = 80
  check_interval_sec      = 20
  timeout_sec             = 15
  healthy_threshold       = 1
  unhealthy_threshold     = 3
}

resource "google_compute_url_map" "default" {
  name            = "apache-url-map"
  default_service = google_compute_backend_service.default.id
}

resource "google_compute_target_http_proxy" "default" {
  name    = "apache-http-proxy"
  url_map = google_compute_url_map.default.id
}

resource "google_compute_global_forwarding_rule" "default" {
  name       = "apache-forwarding-rule"
  target     = google_compute_target_http_proxy.default.id
  port_range = "80"
}

data "google_compute_instance_group" "default" {
  # Reference the instance group created by the instance group manager
  # Use the instance_group attribute from the instance group manager
  self_link = google_compute_instance_group_manager.default.instance_group
}

output "vm_ips" {
  value = [for instance in data.google_compute_instance_group.default.instances : instance.network_interface[0].access_config[0].nat_ip]
  sensitive = true
}

resource "null_resource" "generate_ansible_inventory" {
  provisioner "local-exec" {
    command = <<EOT
      # Get the VM IPs as JSON
      terraform output -json vm_ips | jq -r '
        .[] | 
        {"hosts": ("web_ansible-" + tostring), "ansible_host": .}
      ' > temp_inventory.json

      # Begin the inventory file
      echo "all:" > inventory.gcp.yml
      echo "  children:" >> inventory.gcp.yml
      echo "    web:" >> inventory.gcp.yml
      echo "      hosts:" >> inventory.gcp.yml

      # Append IPs as individual hosts
      jq -r '.[] | "        \(.hosts):\n          ansible_host: \(.ansible_host)\n          ansible_user: centos\n          ansible_ssh_private_key_file: /var/lib/jenkins/.ssh/id_rsa"' temp_inventory.json >> inventory.gcp.yml

      # Clean up
      rm temp_inventory.json
    EOT
    working_dir = path.module
  }

  depends_on = [google_compute_instance_group_manager.default]
}

