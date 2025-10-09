output "jumphost_public_ip" {
  value = module.compute.jumphost_public_ip
}

output "private_instance_internal_ip" {
  value = module.compute.private_ip
}
