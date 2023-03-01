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
  region             = coalesce(var.region, "us-central1") # Need a region for SNEGs, even if backend is global
  http_port          = 80
  https_port         = 443
  network_tier       = local.lb_scheme == "EXTERNAL_MANAGED" ? "STANDARD" : null
  purpose            = local.lb_scheme == "INTERNAL_MANAGED" ? "SHARED_LOADBALANCER_VIP" : null
  network_name       = coalesce(var.network_name, "default")
  network_project_id = coalesce(var.network_project_id, var.project_id) # needed for Shared VPC scenarios
  network_link       = "projects/${local.network_project_id}/global/networks/${local.network_name}"
  network            = endswith(local.lb_scheme, "_MANAGED") ? local.network_link : null
  subnet_prefix      = "projects/${local.network_project_id}/regions"
  subnet_id          = local.is_internal ? "${local.subnet_prefix}/${var.region}/subnetworks/${var.subnet_name}" : null
  subnetwork         = local.is_internal ? local.subnet_id : null
  backend_types = {
    instanceGroups = "instance_groups"
  }
  backends = { for k, backend in var.backends : k => {
    # Determine backend type by seeing if a key has been created for IG, SNEG, or INEG
    #type = coalesce(length(coalesce(backend.groups, [])) > 0 ?
      #  [ for group in coalesce(backend.groups, []) : lookup(local.backend_types, element(split("/", group), 4), null) ]
    type = coalesce(backend.type,
      length(coalesce(lookup(backend, "migs", null), [])) > 0 ? "instance_groups" : null,
      length(coalesce(lookup(backend, "umigs", null), [])) > 0 ? "instance_groups" : null,
      length(coalesce(lookup(backend, "instance_groups", null), [])) > 0 ? "instance_groups" : null,
      length(coalesce(lookup(backend, "snegs", null), [])) > 0 ? "sneg" : null,
      lookup(backend, "ineg", null) != null ? "ineg" : null,
      lookup(backend, "bucket_name", null) != null ? "bucket" : null,
      "unknown" # this should never happen
    )
  } if backend.enable != false }
}

resource "random_string" "name_prefix" {
  count   = var.name_prefix == null ? 1 : 0
  length  = 8
  upper   = false
  special = false
  numeric = false
}
