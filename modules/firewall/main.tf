resource "google_compute_firewall" "allow_ssh_jump" {
  name    = "allow-ssh-jump"
  network = var.network_self_link

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [var.user_ip]
  target_tags   = ["jump-host"]
}

resource "google_compute_firewall" "allow_http_https_jump" {
  name    = "allow-http-https-jump"
  network = var.network_self_link

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["jump-host"]
}

resource "google_compute_firewall" "allow_internal_to_private_80" {
  name    = "allow-internal-to-private-80"
  network = var.network_self_link

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = [var.subnet_small_cidr]
  target_tags   = ["private-host"]
}
