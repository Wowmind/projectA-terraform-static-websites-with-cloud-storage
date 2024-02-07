terraform {
  required_providers {
    google = {
        source = "hashicorp/google"
        version = "5.15.0"
    }
  }
}
provider "google" {
    credentials = "credentials.json"
    project = var.project
    region = var.region
    zone = var.zone
   
}