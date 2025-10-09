variable "project_id" {
  description = "GCP project id"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "europe-west1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "europe-west1-b"
}

variable "network_name" {
  description = "VPC name"
  type        = string
  default     = "devops-vpc"
}

variable "subnet_public_cidr" {
  description = "CIDR for public subnet (jumphost)"
  type        = string
  default     = "10.10.1.0/29"
}

variable "subnet_private_cidr" {
  description = "CIDR for private subnet"
  type        = string
  default     = "10.10.2.0/28"
}

variable "machine_type" {
  description = "Instance machine type"
  type        = string
  default     = "e2-micro"
}

variable "image_family" {
  description = "Image family (Ubuntu LTS)"
  type        = string
  default     = "ubuntu-2204-lts"
}

variable "image_project" {
  description = "Image project"
  type        = string
  default     = "ubuntu-os-cloud"
}

variable "devops_ssh_public_key" {
  description = "SSH key for devops user"
  type        = string
}

variable "domain_name" {
  description = "Domain for HTTPS"
  type        = string
  default     = "babenkov.pp.ua"
}
