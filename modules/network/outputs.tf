output "vpc_self_link" {
  value = google_compute_network.vpc.self_link
}

output "public_self_link" {
  value = google_compute_subnetwork.public.self_link
}

output "private_self_link" {
  value = google_compute_subnetwork.private.self_link
}
