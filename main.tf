data "external" "my_ip" {
  program = ["bash", "./get_my_ip.sh"]
}

module "network" {
  source              = "./modules/network"
  network_name        = var.network_name
  subnet_public_cidr  = var.subnet_public_cidr
  subnet_private_cidr = var.subnet_private_cidr
  region              = var.region
}

module "nat" {
  source                   = "./modules/nat"
  network_name             = var.network_name
  network_self_link        = module.network.vpc_self_link
  region                   = var.region
  subnet_private_self_link = module.network.private_self_link
}

module "firewall" {
  source            = "./modules/firewall"
  network_self_link = module.network.vpc_self_link
  user_ip           = data.external.my_ip.result.ip
  subnet_small_cidr = var.subnet_public_cidr
}

module "compute" {
  source                   = "./modules/compute"
  region                   = var.region
  zone                     = var.zone
  machine_type             = var.machine_type
  image_family             = var.image_family
  image_project            = var.image_project
  network_self_link        = module.network.vpc_self_link
  subnet_small_self_link   = module.network.public_self_link
  subnet_private_self_link = module.network.private_self_link
  # subnet_small_cidr        = var.subnet_public_cidr
  devops_ssh_public_key = var.devops_ssh_public_key
  domain_name           = var.domain_name
}
