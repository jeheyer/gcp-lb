locals {
  upload_ssl_certs = var.ssl_certs != null ? true : false
  use_ssc          = local.is_http ? coalesce(var.use_ssc, var.ssl_certs == null && var.ssl_cert_names == null ? true : false) : false
  use_gmc          = local.is_http && local.is_global ? coalesce(var.use_gmc, false) : false
  certs_to_upload = { for k, v in coalesce(var.ssl_certs, {}) : k => {
    # If cert and key lengths are under 256 bytes, we assume they are the file names
    certificate = length(v.certificate) < 256 ? file("./${v.certificate}") : v.certificate
    private_key = length(v.private_key) < 256 ? file("./${v.private_key}") : v.private_key
    description = v.description #coalesce(each.value.description, "Uploaded via Terraform")
  } if !local.use_ssc && !local.use_gmc }
}

# If required, create a private key
resource "tls_private_key" "default" {
  count     = local.is_http && local.use_ssc ? 1 : 0
  algorithm = var.key_algorithm
  rsa_bits  = var.key_bits
}

# If required, generate a self-signed cert off the private key
resource "tls_self_signed_cert" "default" {
  count           = local.is_http && local.use_ssc ? 1 : 0
  private_key_pem = one(tls_private_key.default).private_key_pem
  subject {
    common_name  = var.domains != null ? var.domains[0] : "localhost.localdoamin"
    organization = "Honest Achmed's Used Cars and Certificates"
  }
  validity_period_hours = 7 * 24
  allowed_uses          = ["key_encipherment", "digital_signature", "server_auth"]
}

# Upload SSL Certs
resource "google_compute_ssl_certificate" "default" {
  for_each    = local.is_global ? local.certs_to_upload : {}
  project     = var.project_id
  name        = local.use_ssc ? null : each.key
  name_prefix = local.use_ssc ? local.name_prefix : null
  certificate = local.use_ssc ? one(tls_self_signed_cert.default).cert_pem : each.value.certificate
  private_key = local.use_ssc ? one(tls_private_key.default).private_key_pem : each.value.private_key
  lifecycle {
    create_before_destroy = true
  }
}
resource "google_compute_region_ssl_certificate" "default" {
  for_each    = local.is_regional ? local.certs_to_upload : {}
  project     = var.project_id
  name        = local.use_ssc ? null : each.key
  name_prefix = local.use_ssc ? local.name_prefix : null
  certificate = local.use_ssc ? one(tls_self_signed_cert.default).cert_pem : each.value.certificate
  private_key = local.use_ssc ? one(tls_private_key.default).private_key_pem : each.value.private_key
  lifecycle {
    create_before_destroy = true
  }
  region = local.region
}

# Google-Managed SSL certificates (Global only)
resource "google_compute_managed_ssl_certificate" "default" {
  count = local.is_global && local.use_gmc ? 1 : 0
  name  = local.name_prefix
  managed {
    domains = var.domains
  }
  project = var.project_id
}
