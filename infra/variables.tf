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

variable "ssh_user" {
  description = "Linux user created on the VM for SSH (ssh <this>@<ip>)."
  type        = string
  default     = "deploy"
}

variable "ssh_public_key" {
  description = "Public key allowed to SSH in (contents of the .pub file). Public: not a secret."
  type        = string
}

variable "ssh_source_ranges" {
  description = "Who may reach port 22. 0.0.0.0/0 because GitHub runners have no fixed IP."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
