variable "region" {
  description = "Region to deploy"
  default     = "europe-west1"
  type        = string
}

variable "zone" {
  description = "Zone to deploy"
  default     = "europe-west1-b"
  type        = string
}

variable "billing_account" {
  description = "Billing account for this project"
  default     = "0183E5-447B34-776DEB"
  type        = string
}

variable "org_id" {
  description = "Billing account for this project"
  default     = "775566979306"
  type        = string
}

variable "project_name" {
  description = "Project name"
  default     = "tsb-single-vm"
  type        = string

}

variable "tags" {
  description = "Resource tags"
  default = {
    tetrate_owner    = "bart"
    tetrate_team     = "sales_se"
    tetrate_purpose  = "demo"
    tetrate_lifespan = "oneoff"
    tetrate_customer = "internal"
  }
  type = object({
    tetrate_owner    = string
    tetrate_team     = string
    tetrate_purpose  = string
    tetrate_lifespan = string
    tetrate_customer = string
  })
}

variable "ssh" {
  description = "SSH login data"
  default = {
    user = "bartvanbos"
    key  = "~/.ssh/id_rsa.pub"
  }
  type = object({
    user = string
    key  = string
  })
}

variable "docker_port" {
  description = "Port for Docker daemon"
  default     = "2376"
  type        = string
}

variable "vm_machine_type" {
  description = "VM machine type"
  default     = "n1-standard-2"
  type        = string
}

variable "vm_name" {
  description = "VM name"
  default     = "istio-single-vm"
  type        = string
}