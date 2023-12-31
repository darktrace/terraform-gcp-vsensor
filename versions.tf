terraform {
  required_version = ">= 1.4"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.79"
    }

    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 4.79"
    }

    random = {
      source  = "hashicorp/random"
      version = "~>3.5"
    }
  }

}
