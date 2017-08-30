variable project_id {
  description = "The project ID to add the IAM bindings for the service account to"
}

variable storage_bucket {
  description = "Name of the GCS bucket for the Vault backend storage"
}

variable network {
  description = "The network to deploy to"
  default     = "default"
}

variable subnetwork {
  description = "The subnetwork to deploy to"
  default     = "default"
}

variable region {
  description = "The region to create the instance in."
}

variable zone {
  description = "The zone to create the instance in."
}

variable machine_type {
  description = "The machine type for the instance"
  default     = "n1-standard-1"
}

variable vault_version {
  description = "The version of vault to install."
  default     = "0.8.1"
}

variable vault_args {
  description = "Additional command line arguments passed to vault server"
  default     = ""
}

variable force_destroy_bucket {
  description = "Set to true to force deletion of backend bucket on terraform destroy"
  default     = false
}