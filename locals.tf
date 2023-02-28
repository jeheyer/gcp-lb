locals {
  name_prefix        = var.name_prefix != null ? var.name_prefix : random_string.name_prefix[0].result
  is_global          = var.region == null ? true : false
  is_regional        = local.is_global ? false : true
  is_classic         = local.is_global && var.classic == true ? true : false
  type               = var.ports != null || var.all_ports || var.global_access ? "TCP" : "HTTP"
  is_tcp             = local.type == "TCP" ? true : false
  is_http            = local.is_classic || startswith(local.type, "HTTP") || var.routing_rules != {} && !local.is_tcp ? true : false
  is_internal        = var.subnet_name != null ? true : false
  lb_scheme          = local.is_http ? local.http_lb_scheme : (local.is_internal ? "INTERNAL" : "EXTERNAL")
  http_lb_scheme     = local.is_internal ? "INTERNAL_MANAGED" : (local.is_classic ? "EXTERNAL" : "EXTERNAL_MANAGED")
  region             = coalesce(var.region, "us-central1")              # Need a region for SNEGs, even if backend is global
  network_project_id = coalesce(var.network_project_id, var.project_id) # needed for Shared VPC scenarios
  http_port          = 80
  https_port         = 443
  backends = { for k, v in var.backends : k => {
    # Determine backend type by seeing if a key has been created for IG, SNEG, or INEG
    type = coalesce(
      lookup(local.instance_groups, k, null) != null ? "instance_groups" : null,
      lookup(local.snegs, k, null) != null ? "sneg" : null,
      lookup(local.inegs, k, null) != null ? "ineg" : null,
      lookup(local.backend_buckets, k, null) != null ? "bucket" : null,
      "unknown" # this should never happen
    )
  } if v.enable != false }
}

resource "random_string" "name_prefix" {
  count   = var.name_prefix == null ? 1 : 0
  length  = 8
  upper   = false
  special = false
  numeric = false
}
