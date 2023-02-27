locals {
  # I'm gonna make a wild assumption and say we want TLS 1.2 or higher w/ good ciphers unless specified otherwise
  min_tls_version = coalesce(var.min_tls_version, "TLS_1_2")
  tls_profile     = coalesce(var.tls_profile, "MODERN")
}

# Global Custom SSL/TLS Policy
resource "google_compute_ssl_policy" "default" {
  count           = var.ssl_policy_name == null && local.is_http && local.is_global ? 1 : 0
  project         = var.project_id
  name            = "${local.name_prefix}-${lower(replace(local.min_tls_version, "_", "-"))}-${lower(local.tls_profile)}"
  profile         = var.tls_profile
  min_tls_version = var.min_tls_version
}

/* Regional Custom SSL/TLS Policy - Still in Beta, will do this later
resource "google_compute_region_ssl_policy" "default" {
  count           = var.ssl_policy_name == null && local.is_http && local.is_regional ? 1 : 0
  project         = var.project_id
  name            = "${local.name_prefix}-${lower(replace(local.min_tls_version, "_", "-"))}-${lower(local.tls_profile)}"
  profile         = var.tls_profile
  min_tls_version = var.min_tls_version
  region  = local.region
} */