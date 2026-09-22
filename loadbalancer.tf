resource "google_compute_region_backend_service" "vsensor" {
  name                            = "${local.deployment_id}-lb-backend"
  description                     = "TCP Load Balancer for accepting Traffic Mirroring"
  project                         = var.project_id
  region                          = var.region
  health_checks                   = [google_compute_health_check.vsensor.self_link]
  connection_draining_timeout_sec = 300
  load_balancing_scheme           = "INTERNAL"
  network                         = local.network_name

  backend {
    balancing_mode = "CONNECTION"
    group          = google_compute_region_instance_group_manager.vsensor.instance_group
  }
}

resource "google_compute_forwarding_rule" "vsensor" {
  name                   = "${local.deployment_id}-fwd-rule"
  description            = "Front end forwarding config for vSensor Traffic Mirroring"
  provider               = google-beta
  region                 = var.region
  project                = data.google_project.project.number
  ip_protocol            = "TCP"
  all_ports              = true
  load_balancing_scheme  = "INTERNAL"
  backend_service        = google_compute_region_backend_service.vsensor.self_link
  network                = local.network_name
  subnetwork             = google_compute_subnetwork.vsensor.self_link
  ip_address             = google_compute_address.vsensor_lb.address
  is_mirroring_collector = true

  allow_global_access = var.lb_global_access_enable
}

resource "google_compute_packet_mirroring" "vsensor" {
  count = local.mirroring_policy ? 1 : 0

  #Workaround to change the ip_protocols value from Allow specific protocols to Allow all protocols
  #Changing the description will replace the resource instead of trying "update in-place" which doesn't work
  description = "Packet mirroring policy - ${local.filter_description}"

  name    = "${local.deployment_id}-mirroring-policy"
  project = var.project_id
  region  = var.region

  network {
    url = local.network_self_link
  }
  collector_ilb {
    url = google_compute_forwarding_rule.vsensor.name
  }
  mirrored_resources {
    dynamic "subnetworks" {
      for_each = toset(var.mirrored_subnets)

      content {
        url = subnetworks.value
      }
    }
  }

  filter {
    ip_protocols = var.mirrored_protocols
    cidr_ranges  = var.mirrored_cidr_ranges
    direction    = var.mirrored_direction
  }
}
