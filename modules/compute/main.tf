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

  metadata_startup_script = templatefile("${path.module}/startup_jump.sh.tpl", {
    ELASTIC_HOST          = "https://elasticsearch.babenkov.pp.ua:9200"
    KIBANA_HOST           = "https://kibana.babenkov.pp.ua:5601"
    ELASTIC_USERNAME      = "elastic"
    ELASTIC_PASSWORD      = "your_elastic_password"
    DOMAIN_NAME           = var.domain_name
    DEVOPS_SSH_PUBLIC_KEY = var.devops_ssh_public_key
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
