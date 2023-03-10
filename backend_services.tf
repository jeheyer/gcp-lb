
locals {
  default_balancing_mode = local.type == "TCP" ? "CONNECTION" : "UTILIZATION"
  locality_lb_policy     = endswith(local.lb_scheme, "_MANAGED") ? "ROUND_ROBIN" : null
  hc_prefix              = "projects/${var.project_id}/${local.is_regional ? "regions/${var.region}" : "global"}/healthChecks"
  backend_services = { for k, v in var.backends : k => {
    # Determine backend type by seeing if a key has been created for IG, SNEG, or INEG
    type = coalesce(
      length(coalesce(v.groups, [])) > 0 ? "instance_groups" : null, # temp until SNEG support fully works
      lookup(local.instance_groups, k, null) != null ? "instance_groups" : null,
      lookup(local.snegs, k, null) != null ? "sneg" : null,
      lookup(local.inegs, k, null) != null ? "ineg" : null,
      "unknown" # this should never happen
    )
    description     = coalesce(v.description, "Backend Service '${k}'")
    region          = local.is_regional ? coalesce(v.region, local.region) : null # Set region, if required
    protocol        = lookup(local.snegs, k, null) != null ? null : local.is_http ? upper(coalesce(v.protocol, try(one(local.inegs[k]).protocol, null), "https")) : null
    port_name       = local.is_http ? coalesce(v.port, 80) == 80 ? "http" : coalesce(v.port_name, "${k}-${coalesce(v.port, 80)}") : null
    timeout         = lookup(local.snegs, k, null) != null ? null : coalesce(v.timeout, var.backend_timeout, 30)
    healthcheck_ids = v.healthchecks != null ? [for hc in v.healthchecks : coalesce(hc.id, try("${local.hc_prefix}/${hc.name}", null))] : []
    groups = coalesce(v.groups,
      lookup(local.instance_groups, k, null) != null ? local.instance_groups[k].ids : null,
      lookup(local.snegs, k, null) != null ? [google_compute_region_network_endpoint_group.default[k].id] : null,
      local.is_global ? (lookup(local.inegs, k, null) != null ? [google_compute_global_network_endpoint_group.default[k].id] : null) : null,
      [] # This will result in 'has no backends configured' which is easier to troubleshoot than an ugly error
    )
    logging               = coalesce(v.logging, var.backend_logging, false)
    logging_rate          = local.is_http ? (coalesce(v.logging, false) ? coalesce(v.logging_rate, 1.0) : null) : null
    enable_cdn            = local.is_http ? coalesce(v.enable_cdn, false) : null
    security_policy       = local.is_http ? try(coalesce(v.cloudarmor_policy, var.cloudarmor_policy), null) : null
    affinity_type         = coalesce(v.affinity_type, "NONE")
    capacity_scaler       = endswith(local.lb_scheme, "_MANAGED") ? coalesce(v.capacity_scaler, 1.0) : null
    max_connections       = local.is_global && local.type == "TCP" ? coalesce(v.max_connections, 32768) : null
    max_utilization       = endswith(local.lb_scheme, "_MANAGED") ? coalesce(v.max_utilization, 0.8) : null
    max_rate_per_instance = endswith(local.lb_scheme, "_MANAGED") ? coalesce(v.max_rate_per_instance, 512) : null
  } if lookup(local.backend_buckets, k, null) == null && v.bucket_name == null && v.type != "bucket" }
}

# Global Backend Service
resource "google_compute_backend_service" "default" {
  for_each              = local.is_global ? local.backend_services : {}
  project               = var.project_id
  name                  = "${local.name_prefix}-${each.key}"
  load_balancing_scheme = local.lb_scheme
  locality_lb_policy    = local.locality_lb_policy
  protocol              = each.value.protocol
  port_name             = each.value.port_name
  timeout_sec           = each.value.timeout
  health_checks         = each.value.type == "instance_groups" ? local.backend_services[each.key].healthcheck_ids : null
  session_affinity      = each.value.type == "instance_groups" ? each.value.affinity_type : null
  security_policy       = each.value.security_policy
  dynamic "backend" {
    for_each = each.value.groups
    content {
      group                 = backend.value
      capacity_scaler       = local.backend_services[each.key].capacity_scaler
      balancing_mode        = each.value.type == "ineg" ? null : local.default_balancing_mode
      max_rate_per_instance = each.value.type == "instance_groups" ? local.backend_services[each.key].max_rate_per_instance : null
      max_utilization       = each.value.type == "instance_groups" ? local.backend_services[each.key].max_utilization : null
      max_connections       = each.value.type == "instance_groups" ? local.backend_services[each.key].max_connections : null
    }
  }
  dynamic "log_config" {
    for_each = each.value.logging ? [true] : []
    content {
      enable      = true
      sample_rate = each.value.logging_rate
    }
  }
  depends_on = [google_compute_instance_group.default]
}

# Regional Backend Service
resource "google_compute_region_backend_service" "default" {
  for_each              = local.is_regional ? local.backend_services : {}
  project               = var.project_id
  name                  = "${local.name_prefix}-${each.key}"
  load_balancing_scheme = local.lb_scheme
  locality_lb_policy    = local.locality_lb_policy
  description           = each.value.description
  protocol              = each.value.protocol
  port_name             = each.value.port_name
  timeout_sec           = each.value.timeout
  health_checks         = each.value.type == "instance_groups" ? local.backend_services[each.key].healthcheck_ids : null
  session_affinity      = each.value.type == "instance_groups" ? each.value.affinity_type : null
  #security_policy = each.value.security_policy
  dynamic "backend" {
    for_each = each.value.groups
    content {
      group                 = backend.value
      capacity_scaler       = local.backend_services[each.key].capacity_scaler
      balancing_mode        = each.value.type == "ineg" ? null : local.default_balancing_mode
      max_rate_per_instance = each.value.type == "instance_groups" ? local.backend_services[each.key].max_rate_per_instance : null
      max_utilization       = each.value.type == "instance_groups" ? local.backend_services[each.key].max_utilization : null
      max_connections       = each.value.type == "instance_groups" ? local.backend_services[each.key].max_connections : null
    }
  }
  dynamic "log_config" {
    for_each = each.value.logging ? [true] : []
    content {
      enable      = true
      sample_rate = each.value.logging_rate
    }
  }
  region     = each.value.region
  depends_on = [google_compute_instance_group.default]
}
