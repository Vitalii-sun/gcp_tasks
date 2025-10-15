resource "google_compute_router" "router" {
  name    = "${var.network_name}-router"
  network = var.network_self_link
  region  = var.region
}
resource "google_compute_router_nat" "nat" {
  name                               = "${var.network_name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = var.subnet_private_self_link
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}
