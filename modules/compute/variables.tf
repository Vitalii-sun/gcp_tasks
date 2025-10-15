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

variable "devops_ssh_public_key" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "elastic_host" {
  type        = string
  default = "elasticsearch.babenkov.pp.ua"
}

variable "kibana_host" {
  type        = string
  default = "kibana.babenkov.pp.ua"
}

variable "elastic_username" {
  type        = string
  default = "elastic"
}

variable "elastic_password" {
  type        = string
  default = "password"
}

variable "private_ip" {
  type        = string
  default     = "10.10.2.2"
}

