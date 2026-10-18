output "vm_name" {
  description = "Repository variable VM_NAME for the app pipeline."
  value       = google_compute_instance.app.name
}

output "zone" {
  description = "Repository variable GCP_ZONE for the app pipeline."
  value       = google_compute_instance.app.zone
}

output "app_url" {
  description = "Open it in the browser once the app pipeline deployed."
  value       = "http://${google_compute_instance.app.network_interface[0].access_config[0].nat_ip}:8080/"
}

output "ssh_command" {
  description = "How to get in by hand."
  value       = "ssh -i ~/.ssh/clase4 ${var.ssh_user}@${google_compute_instance.app.network_interface[0].access_config[0].nat_ip}"
}
