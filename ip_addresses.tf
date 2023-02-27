locals {
  ip_versions  = local.is_global ? concat(var.enable_ipv4 ? ["IPV4"] : [], var.enable_ipv6 ? ["IPV6"] : []) : ["IPV4"]
  address_type = local.is_internal ? "INTERNAL" : "EXTERNAL"
  addresses = {
    "ipv4" = try(coalesce(var.ipv4_address, var.ip_address), null)
    "ipv6" = try(coalesce(var.ipv6_address), null)
  }
}

# Global static IP
resource "google_compute_global_address" "default" {
  for_each     = local.is_global ? { for i, v in local.ip_versions : lower(v) => upper(v) } : {}
  project      = var.project_id
  name         = "${local.name_prefix}-${each.key}-${local.is_internal ? "ilb" : "elb"}"
  address_type = local.address_type
  ip_version   = each.value
  address      = local.addresses[each.key]
}

# Locals for regional and/or internal LBs
locals {
  network_tier  = local.lb_scheme == "EXTERNAL_MANAGED" ? "STANDARD" : null
  purpose       = local.lb_scheme == "INTERNAL_MANAGED" ? "SHARED_LOADBALANCER_VIP" : null
  network_name  = coalesce(var.network_name, "default")
  network       = endswith(local.lb_scheme, "_MANAGED") ? local.network_name : null
  subnet_prefix = "projects/${local.network_project_id}/regions"
  subnet_id     = local.is_internal ? "${local.subnet_prefix}/${var.region}/subnetworks/${var.subnet_name}" : null
  subnetwork    = local.is_internal ? local.subnet_id : null
}

# Regional static IP
resource "google_compute_address" "default" {
  for_each     = local.is_regional ? { for i, v in local.ip_versions : lower(v) => upper(v) } : {}
  project      = var.project_id
  name         = "${local.name_prefix}-${local.is_internal ? "ilb" : "elb"}-${each.key}"
  address_type = local.address_type
  region       = local.region
  subnetwork   = local.subnetwork
  network_tier = local.network_tier
  purpose      = local.purpose
  address      = local.addresses[each.key]
}