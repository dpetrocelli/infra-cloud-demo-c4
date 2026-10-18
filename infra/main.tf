# Class 4 demo: ONE VM with Docker, ready to `docker pull` and run the app.
# The infra pipeline (.github/workflows/infra.yml) applies this; the app
# pipeline only deploys containers onto it and never touches this code.

terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # Same state bucket as the course template, its own prefix.
  # bucket comes from -backend-config (it carries the project id).
  backend "gcs" {
    prefix = "demo-c4"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

resource "google_compute_instance" "app" {
  name         = var.vm_name
  machine_type = var.machine_type
  tags         = ["demo-c4"]

  labels = {
    managed_by = "opentofu"
    clase      = "4"
    demo       = "en-vivo"
  }

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
    }
  }

  network_interface {
    network = "default"
    access_config {} # public IP, to open the app from the browser
  }

  # OS Login: SSH access is granted with IAM roles, not with keys in metadata.
  # The app pipeline deploys over SSH as its own service account.
  metadata = {
    enable-oslogin = "TRUE"
  }

  # Docker only. No app here: the app arrives later, with `docker pull`.
  metadata_startup_script = file("${path.module}/startup.sh")

  # The VM pulls from Artifact Registry as the default compute account
  # (it already has roles/artifactregistry.reader in this project).
  service_account {
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_firewall" "app" {
  name          = "${var.vm_name}-allow-app"
  network       = "default"
  target_tags   = ["demo-c4"]
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }
}

# SSH only through IAP (Google's range), not from the internet.
resource "google_compute_firewall" "ssh_iap" {
  name          = "${var.vm_name}-allow-ssh-iap"
  network       = "default"
  target_tags   = ["demo-c4"]
  source_ranges = ["35.235.240.0/20"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
