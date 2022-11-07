provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
  credentials = file("creds.json")
}

resource "google_compute_network" "network" {
  name                    = "${var.name}-network"
  auto_create_subnetworks = false
}

# backend subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "${var.name}-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.network.id
}

resource "google_compute_firewall" "this" {
  name    = "${var.name}-allow-healthcheck"
  network = google_compute_network.network.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  priority = 1000
}

resource "google_compute_instance_template" "this" {
  name        = "${var.name}-${var.deploy_version}"

   tags = var.tags

  labels = {
    service = var.name
    version = var.deploy_version
  }

  metadata = {
    version = var.deploy_version
    block-project-ssh-keys = true
  }

  machine_type            = var.machine_type
  can_ip_forward          = false
  metadata_startup_script = "${file("./script.sh")}"

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  disk {
    source_image = var.image
    boot         = true
    disk_type    = "pd-balanced"
  }

  network_interface {
    network    = google_compute_network.network.name
    subnetwork = google_compute_subnetwork.subnet.name
  }

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = "terraformacc@model-azimuth-365511.iam.gserviceaccount.com"
    scopes = ["cloud-platform"]
  }

  lifecycle {
    create_before_destroy = true
  }

}


resource "google_compute_instance_group_manager" "this" {
    name        = var.name

  base_instance_name = var.name
  zone               = var.zone

  version {
    name               = var.deploy_version
    instance_template  = google_compute_instance_template.this.id
  }

  target_size = var.minimum_vm_size

  named_port {
    name = "web"
    port = 80
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.autohealing.id
    initial_delay_sec = 60
  }

}

resource "google_compute_health_check" "autohealing" {
  name                = "${var.name}-autohealing"
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 10

  http_health_check {
    request_path = "/"
    port         = "80"
  }
}

resource "google_compute_autoscaler" "this" {
  name   = "${var.name}-autoscaler"
  zone   = var.zone
  target = google_compute_instance_group_manager.this.id

  autoscaling_policy {
    max_replicas    = 4
    min_replicas    = var.minimum_vm_size
    cooldown_period = 30

    cpu_utilization {
      target = 0.72
    }
  }

  depends_on = [ google_compute_instance_group_manager.this ]
}

resource "google_compute_global_address" "this" {
  name = "${var.name}-ipv4"
}

resource "google_compute_url_map" "http" {
  name = "${var.name}-http"

  default_url_redirect {
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
    https_redirect         = true
  }
}

resource "google_compute_target_http_proxy" "http" {
  name    = "${var.name}-http"
  url_map = google_compute_url_map.http.self_link
}

resource "google_compute_global_forwarding_rule" "http" {
  name       = "${var.name}-http"
  target     = google_compute_target_http_proxy.http.self_link
  ip_address = google_compute_global_address.this.address
  port_range = "80"
}

output "Loadbalancer-IPv4-Address" {
   value = google_compute_global_address.this.address
}

resource "google_compute_backend_service" "this" {
  name        = var.name
  port_name   = "http"
  protocol    = "HTTP"
  timeout_sec = 10

  health_checks = [google_compute_http_health_check.this.id]

  backend {
   group                 = google_compute_instance_group_manager.this.instance_group
   balancing_mode        = "RATE"
   capacity_scaler       = 1.0
   max_rate_per_instance = 500
  }
}

resource "google_compute_http_health_check" "this" {
  name               = "${var.name}-healthcheck"
  request_path       = "/"
  check_interval_sec = 1
  timeout_sec        = 1
}