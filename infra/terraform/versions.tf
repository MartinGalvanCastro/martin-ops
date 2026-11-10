terraform {
  required_version = ">= 1.12" # backend "oci" nativo

  # Bucket creado a mano una vez (README). Lock de state nativo del backend.
  backend "oci" {
    bucket    = "martin-ops-tfstate"
    namespace = "axvmef9kdxvh"
    key       = "martin-ops/terraform.tfstate"
    region    = "us-chicago-1"
    auth      = "APIKey"
  }

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 9.11"
    }
  }
}

provider "oci" {
  region = var.region
  auth   = "ApiKey"
}
