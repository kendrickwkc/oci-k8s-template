variable "name" {
  description = "Tenant name (lowercase, used as resource/prefix/k8s service name)"
  type        = string
}

variable "zone" {
  description = "Cloudflare zone (domain) name, e.g. example.com"
  type        = string
}

variable "hostname" {
  description = "Hostname within the zone for the app (use \"@\" for apex, or a subdomain label)"
  type        = string
  default     = "@"
}

variable "app_service" {
  description = "Upstream service the Cloudflare tunnel routes to (k8s service URL)"
  type        = string
  default     = null
}

variable "cf_account_id" {
  description = "Cloudflare account ID"
  type        = string
}

variable "tenancy_id" {
  description = "OCI tenancy (root compartment) OCID — identity resources must live here"
  type        = string
}

variable "compartment_id" {
  description = "OCI compartment OCID (buckets and policy live here)"
  type        = string
}

variable "region" {
  description = "OCI region (resources; also the assets Worker's SigV4 region when worker_storage_backend = \"oci\")"
  type        = string
}

variable "buckets" {
  description = "Object Storage buckets to create and grant the tenant identity access to"
  type        = list(string)
}

variable "worker_enabled" {
  description = "Create a Cloudflare Worker that serves a bucket (OCI S3-compat by default, or a native R2 binding when worker_storage_backend = \"r2\")"
  type        = bool
  default     = false
}

variable "assets_bucket" {
  description = "OCI bucket served by the assets Worker (required when worker_enabled and worker_storage_backend = \"oci\")"
  type        = string
  default     = null

  validation {
    condition     = !var.worker_enabled || var.worker_storage_backend == "r2" || var.assets_bucket != null
    error_message = "assets_bucket is required when worker_enabled is true and worker_storage_backend is \"oci\""
  }
}

variable "worker_storage_backend" {
  description = "Storage backend the assets Worker reads from: \"oci\" (S3-compat + SigV4) or \"r2\" (native R2 bucket binding)"
  type        = string
  default     = "oci"

  validation {
    condition     = contains(["oci", "r2"], var.worker_storage_backend)
    error_message = "worker_storage_backend must be \"oci\" or \"r2\""
  }
}

variable "r2_bucket_name" {
  description = "R2 bucket served by the assets Worker (required when worker_storage_backend = \"r2\")"
  type        = string
  default     = null

  validation {
    condition     = var.worker_storage_backend != "r2" || var.r2_bucket_name != null
    error_message = "r2_bucket_name is required when worker_storage_backend is \"r2\""
  }
}

variable "worker_r2_binding_name" {
  description = "Binding name the assets Worker reads the R2 bucket from (worker_storage_backend = \"r2\")"
  type        = string
  default     = "MEDIA_BUCKET"
}

variable "assets_hostname" {
  description = "Hostname for the assets Worker (defaults to assets.<zone>)"
  type        = string
  default     = null
}

variable "worker_script_path" {
  description = "Path to a custom Worker script (defaults to the module's generic OCI worker.js; required for worker_storage_backend = \"r2\")"
  type        = string
  default     = null

  validation {
    condition     = var.worker_storage_backend != "r2" || var.worker_script_path != null
    error_message = "worker_script_path is required when worker_storage_backend is \"r2\" (the default worker.js targets OCI)"
  }
}

variable "worker_secret_bindings" {
  description = "Extra secret_text bindings for the assets Worker (name => value), e.g. a shared HMAC key"
  type        = map(string)
  default     = {}
  sensitive   = true
}

locals {
  fqdn        = var.hostname == "@" ? var.zone : "${var.hostname}.${var.zone}"
  app_service = var.app_service != null ? var.app_service : "http://${var.name}:8080"
  assets_fqdn = var.assets_hostname != null ? var.assets_hostname : "assets.${var.zone}"
}
