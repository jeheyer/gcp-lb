terraform {
  required_version = ">= 1.3.4"
  required_providers {
    google = {
      version = ">= 4.51.0"
      source  = "hashicorp/google"
    }
  }
}