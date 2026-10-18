variable "project_id" {
  description = "GCP project id."
  type        = string
}

variable "region" {
  description = "Region (the Artifact Registry repository lives here too)."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zone of the VM."
  type        = string
  default     = "us-central1-a"
}

variable "vm_name" {
  description = "Name of the VM. The app pipeline deploys to this name (repository variable VM_NAME)."
  type        = string
  default     = "demo-c4-vm"
}

variable "machine_type" {
  description = "Machine type. e2-small is enough for the demo API."
  type        = string
  default     = "e2-small"
}
