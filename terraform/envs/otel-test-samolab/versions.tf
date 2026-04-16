# ============================================================
# Environment: otel-test-samolab
# ============================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # Uncomment after project is created to use remote state:
  # backend "gcs" {
  #   bucket = "otel-test-samolab-tfstate"
  #   prefix = "terraform/state"
  # }
}

provider "google" {
  region = var.region
}
