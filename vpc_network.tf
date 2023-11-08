resource "google_compute_subnetwork" "vsensor" {
  name          = "${local.deployment_id}-vsensor-subnet"
  ip_cidr_range = var.mig_subnet_cidr
  region        = var.region

  network                  = local.network_name
  private_ip_google_access = true
}

resource "google_compute_address" "vsensor_lb" {
  name         = "${local.deployment_id}-vsensor-lb-ip"
  subnetwork   = google_compute_subnetwork.vsensor.name
  address_type = "INTERNAL"
  address      = local.lb_ip
  region       = var.region
}

resource "google_compute_network" "vsensor" {
  count = var.new_vpc_enable ? 1 : 0

  name = "${local.deployment_id}-vpc"

  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_router" "vsensor" {
  name    = "${local.deployment_id}-router"
  network = local.network_name
  region  = var.region
}

resource "google_compute_address" "vsensor_nat_external" {
  name = "${local.deployment_id}-nat-ip-external"

  address_type = "EXTERNAL"
  network_tier = "PREMIUM"
  region       = var.region
}

resource "google_compute_router_nat" "vsensor" {
  name   = "${local.deployment_id}-nat"
  router = google_compute_router.vsensor.name
  region = var.region

  nat_ip_allocate_option = "MANUAL_ONLY"
  nat_ips                = [google_compute_address.vsensor_nat_external.self_link]

  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetwork {
    name                    = google_compute_subnetwork.vsensor.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

resource "google_compute_firewall" "traffic_mirror" {
  name        = "${local.deployment_id}-traffic-mirror"
  network     = local.network_name
  description = "Allow all packet mirror traffic to be ingested into the vSensors."

  #GCP recommended this such that it always applies over other firewall rules
  priority = "1"

  source_ranges = ["0.0.0.0/0"]

  direction = "INGRESS"

  allow {
    protocol = "all"
  }

  #Apply firewall rule to only vSensors in private MIG.
  target_tags = ["darktrace-vsensor-mirroring"]
}
