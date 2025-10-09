variable "region" {
  type = string
}

variable "zone" {
  type = string
}

variable "machine_type" {
  type = string
}

variable "image_family" {
  type = string
}

variable "image_project" {
  type = string
}

variable "network_self_link" {
  type = string
}

variable "subnet_small_self_link" {
  type = string
}

variable "subnet_private_self_link" {
  type = string
}

# variable "subnet_small_cidr" {
#   type = string
# }

variable "devops_ssh_public_key" {
  type = string
}

variable "domain_name" {
  type = string
}
