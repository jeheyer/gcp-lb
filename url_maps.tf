locals {
  enable_http  = var.http_port != null ? true : false
  enable_https = var.https_port != null ? true : false
}

# Global URL Map for HTTP
resource "google_compute_url_map" "http" {
  count           = local.is_http && local.is_global && local.enable_http ? 1 : 0
  project         = var.project_id
  name            = "${local.name_prefix}-http"
  default_service = null
  default_url_redirect {
    https_redirect = true
    strip_query    = false
  }
}

# Regional URL Map for HTTP
resource "google_compute_region_url_map" "http" {
  count           = local.is_http && local.is_regional && local.enable_http ? 1 : 0
  project         = var.project_id
  name            = "${local.name_prefix}-http"
  default_service = null
  default_url_redirect {
    https_redirect = true
    strip_query    = false
  }
  region = local.region
}

locals {
  backend_ids = { for k, v in var.backends : k =>
    try(coalesce(
      lookup(google_compute_backend_bucket.default, k, null),
      lookup(google_compute_backend_service.default, k, null),
      lookup(google_compute_region_backend_service.default, k, null),
  ).id, null) }
  default_service_id = try(lookup(local.backend_ids, coalesce(var.default_backend, keys(var.backends)[0]), null), null)
}

# Global HTTPS URL MAP
resource "google_compute_url_map" "https" {
  count           = local.is_http && local.is_global && local.enable_https ? 1 : 0
  project         = var.project_id
  name            = "${local.name_prefix}-https"
  default_service = local.default_service_id
  dynamic "host_rule" {
    for_each = coalesce(var.routing_rules, {})
    content {
      path_matcher = host_rule.key
      hosts        = host_rule.value.hosts
    }
  }
  dynamic "path_matcher" {
    for_each = coalesce(var.routing_rules, {})
    content {
      name            = path_matcher.key
      default_service = lookup(local.backend_ids, coalesce(path_matcher.value.backend, path_matcher.key), null)
      dynamic "path_rule" {
        for_each = coalesce(path_matcher.value.path_rules, [])
        content {
          paths   = path_rule.value.paths
          service = path_rule.value.backend
        }
      }
    }
  }
  depends_on = [google_compute_backend_service.default, google_compute_backend_bucket.default]
}
# Regional HTTPS URL MAP
resource "google_compute_region_url_map" "https" {
  count           = local.is_http && local.is_regional && local.enable_https ? 1 : 0
  project         = var.project_id
  name            = "${local.name_prefix}-https"
  default_service = local.default_service_id
  dynamic "host_rule" {
    for_each = coalesce(var.routing_rules, {})
    content {
      path_matcher = host_rule.key
      hosts        = host_rule.value.hosts
    }
  }
  dynamic "path_matcher" {
    for_each = coalesce(var.routing_rules, {})
    content {
      name            = path_matcher.key
      default_service = lookup(local.backend_ids, coalesce(path_matcher.value.backend, path_matcher.key), null)
      dynamic "path_rule" {
        for_each = coalesce(path_matcher.value.path_rules, [])
        content {
          paths   = path_rule.value.paths
          service = path_rule.value.backend
        }
      }
    }
  }
  depends_on = [google_compute_region_backend_service.default]
  region     = local.region
}
