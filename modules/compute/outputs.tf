output "jumphost_public_ip" {
  value = google_compute_instance.jump.network_interface[0].access_config[0].nat_ip
}

output "private_ip" {
  value = google_compute_instance.private.network_interface[0].network_ip
}