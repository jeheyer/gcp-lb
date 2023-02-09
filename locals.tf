locals {
  name_prefix    = coalesce(var.name_prefix, one(random_string.name_prefix).result)
  is_global      = var.region == null ? true : false
  is_regional    = local.is_global ? false : true
  is_classic     = local.is_global && var.classic == true ? true : false
  type           = var.ports != null || var.all_ports || var.global_access ? "TCP" : "HTTP"
  is_tcp         = local.type == "TCP" ? true : false
  is_http        = local.is_classic || startswith(local.type, "HTTP") || var.routing_rules != {} && !local.is_tcp ? true : false
  is_internal    = var.subnet_name != null ? true : false
  lb_scheme      = local.is_http ? local.http_lb_scheme : (local.is_internal ? "INTERNAL" : "EXTERNAL")
  http_lb_scheme = local.is_internal ? "INTERNAL_MANAGED" : (local.is_classic ? "EXTERNAL" : "EXTERNAL_MANAGED")
  region         = coalesce(var.region, "us-central1") # Need a region for SNEGs even if backend is global
}

resource "random_string" "name_prefix" {
  count   = var.name_prefix == null ? 1 : 0
  length  = 5
  upper   = false
  special = false
  numeric = false
}
