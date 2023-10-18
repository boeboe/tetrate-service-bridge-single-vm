terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.2.0"
    }
  }
}

provider "google" {
  region = var.region
}