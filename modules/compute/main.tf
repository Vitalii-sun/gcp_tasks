# data "local_file" "index_html" {
#   filename = "${path.module}/index.html"
# }

data "google_compute_image" "ubuntu" {
  family  = var.image_family
  project = var.image_project
}

resource "google_compute_address" "jump_eip" {
  name   = "jump-eip"
  region = var.region
}

resource "google_compute_instance" "jump" {
  name         = "jump-host"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["jump-host"]

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
    }
  }

  network_interface {
    network    = var.network_self_link
    subnetwork = var.subnet_small_self_link
    access_config {
      nat_ip = google_compute_address.jump_eip.address
    }
  }

  metadata = {
    ssh-keys = "devops:${var.devops_ssh_public_key}"
  }

  metadata_startup_script = templatefile("${path.module}/startup_jump.sh.tpl", {
    ELASTIC_HOST     = var.elastic_host
    KIBANA_HOST      = var.kibana_host
    ELASTIC_USERNAME = var.elastic_username
    ELASTIC_PASSWORD = var.elastic_password
    DOMAIN_NAME      = var.domain_name
    PRIVATE_BACKEND_IP = var.private_ip

  })
}


resource "google_compute_instance" "private" {
  name         = "private-host"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["private-host"]

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
    }
  }

  network_interface {
    network    = var.network_self_link
    subnetwork = var.subnet_private_self_link
  }

  metadata_startup_script = templatefile("${path.module}/startup_private.sh.tpl", {
    devops_ssh_public_key = var.devops_ssh_public_key
  })
}
