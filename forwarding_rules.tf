locals {
  ports     = !local.is_http && length(coalesce(var.ports, [])) > 0 ? var.ports : null
  all_ports = var.all_ports && local.ports == null && var.port_range == null ? true : false
  service_id = local.is_global && !local.is_http ? try(coalesce(
    lookup(google_compute_backend_service.default, coalesce(var.default_backend, var.name_prefix), null),
    ).id, null) : local.is_regional ? try(coalesce(
    lookup(google_compute_region_backend_service.default, coalesce(var.default_backend, keys(var.backends)[0]), null)
  ).id, null) : null
  target_id = local.type == "TCP" || local.type == "SSL" ? try(coalesce(
    local.is_global ? one(google_compute_target_tcp_proxy.default) : null
  ).id, null) : null
  global_fwd_rules = local.is_http ? { for i, v in local.ip_versions : i => { ip_version = lower(v) } } : {
    for i, v in setproduct(local.ip_versions, coalescelist(local.ports, [])) : i => {
      ip_version = lower(v[0])
      port       = tostring(v[1])
    } if !local.all_ports
  }
}

# Global Forwarding rule for TCP or SSL Proxy
resource "google_compute_global_forwarding_rule" "default" {
  for_each              = local.is_global && !local.is_http ? local.global_fwd_rules : {}
  project               = var.project_id
  name                  = "${local.name_prefix}-${each.value.ip_version}-${each.value.port}"
  port_range            = each.value.port
  target                = local.target_id
  ip_address            = google_compute_global_address.default[each.value.ip_version].id
  load_balancing_scheme = local.lb_scheme
  ip_protocol           = local.type
}

# Global Forwarding rule for HTTP
resource "google_compute_global_forwarding_rule" "http" {
  for_each              = local.is_global && local.is_http && local.enable_http ? local.global_fwd_rules : {}
  project               = var.project_id
  name                  = "${local.name_prefix}-${each.value.ip_version}-http"
  port_range            = var.http_port
  target                = one(google_compute_target_http_proxy.default).id
  ip_address            = google_compute_global_address.default[each.value.ip_version].id
  load_balancing_scheme = local.lb_scheme
}

# Global Forwarding Rule for HTTPS
resource "google_compute_global_forwarding_rule" "https" {
  for_each              = local.is_global && local.is_http && local.enable_http ? local.global_fwd_rules : {}
  project               = var.project_id
  name                  = "${local.name_prefix}-${each.value.ip_version}-https"
  port_range            = var.https_port
  target                = one(google_compute_target_https_proxy.default).id
  ip_address            = google_compute_global_address.default[each.value.ip_version].id
  load_balancing_scheme = local.lb_scheme
}

# Regional Forwarding rule for Network or Internal TCP/UDP LB
resource "google_compute_forwarding_rule" "default" {
  count                 = local.is_regional && !local.is_http ? 1 : 0
  project               = var.project_id
  name                  = "${local.name_prefix}-lb"
  port_range            = var.port_range
  ports                 = local.ports
  all_ports             = local.all_ports
  backend_service       = local.service_id
  target                = null
  ip_address            = google_compute_address.default["ipv4"].id
  load_balancing_scheme = local.lb_scheme
  region                = local.region
  network               = local.network
  subnetwork            = local.subnetwork
  network_tier          = local.network_tier
  allow_global_access   = local.is_internal ? coalesce(var.global_access, false) : false
}

# Regional Forwarding rule for HTTP
resource "google_compute_forwarding_rule" "http" {
  count                 = local.is_regional && local.is_http && local.enable_http ? 1 : 0
  project               = var.project_id
  name                  = "${local.name_prefix}-http"
  port_range            = var.http_port
  target                = one(google_compute_region_target_http_proxy.default).id
  ip_address            = google_compute_address.default["ipv4"].id
  load_balancing_scheme = local.lb_scheme
  region                = local.region
  network               = local.network
  subnetwork            = local.subnetwork
  network_tier          = local.network_tier
}

# Regional Forwarding Rule for HTTPS
resource "google_compute_forwarding_rule" "https" {
  count                 = local.is_regional && local.is_http && local.enable_https ? 1 : 0
  project               = var.project_id
  name                  = "${local.name_prefix}-https"
  port_range            = var.https_port
  target                = one(google_compute_region_target_https_proxy.default).id
  ip_address            = google_compute_address.default["ipv4"].id
  load_balancing_scheme = local.lb_scheme
  region                = local.region
  network               = local.network
  subnetwork            = local.subnetwork
  network_tier          = local.network_tier
}

# Prep values for PSC
locals {
  psc = var.psc == null ? null : {
    service_name = coalesce(var.psc.service_name, "${local.name_prefix}-psc")
    nat_subnet_ids = coalesce(
      var.psc.nat_subnet_ids,
      [for sn in var.psc.nat_subnet_names : "${local.subnet_prefix}/${var.region}/subnetworks/${sn}"]
    )
    use_proxy_protocol          = coalesce(var.psc.use_proxy_protocol, false)
    auto_accept_all_connections = coalesce(var.psc.auto_accept_all_connections, false)
    accept_project_ids          = coalesce(var.psc.accept_project_ids, [])
    connection_limit            = coalesce(var.psc.connection_limit, 10)
  }
}

# Private Service Connect Publishing
resource "google_compute_service_attachment" "default" {
  count                 = local.psc != null ? 1 : 0
  project               = var.project_id
  name                  = local.psc.service_name
  region                = local.region
  description           = coalesce(var.psc.description, "PSC Publish for '${local.psc.service_name}'")
  enable_proxy_protocol = local.psc.use_proxy_protocol
  nat_subnets           = local.psc.nat_subnet_ids
  target_service        = one(google_compute_forwarding_rule.default).id
  connection_preference = local.psc.auto_accept_all_connections ? "ACCEPT_AUTOMATIC" : "ACCEPT_MANUAL"
  dynamic "consumer_accept_lists" {
    for_each = local.psc.accept_project_ids
    content {
      project_id_or_num = consumer_accept_lists.value
      connection_limit  = local.psc.connection_limit
    }
  }
}

