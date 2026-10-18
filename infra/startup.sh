#!/bin/bash
# Runs as root on every boot. Installs Docker and lets it pull from Artifact
# Registry with the VM's own service account. Nothing app-specific.
set -euo pipefail

if ! command -v docker >/dev/null; then
  apt-get update
  apt-get install -y docker.io
  systemctl enable --now docker
fi

# gcloud ships with Debian images on GCE; this adds the credential helper for root.
gcloud auth configure-docker us-central1-docker.pkg.dev --quiet
