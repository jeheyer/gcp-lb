locals {
  zones_prefix = "projects/${var.project_id}/zones"
  umigs_with_ids = { for k, backend in var.backends : k => [for umig in coalesce(backend.umigs, []) : {
    # UMIG id was provided; we can determine name and zone by parsing it
    id   = umig.id
    zone = element(split("/", umig.id), 3)
    name = element(split("/", umig.id), 5)
  } if lookup(umig, "id", null) != null] }
  umigs_without_ids = { for k, backend in var.backends : k => [for umig in coalesce(backend.umigs, []) : {
    # UMIG doesn't have the ID, so we'll figure it out using name and zone
    name      = lookup(umig, "name", null)
    zone      = umig.zone
    id        = "${local.zones_prefix}/${umig.zone}/instanceGroups/${umig.name}"
    instances = coalesce(lookup(umig, "instances", null), [])
    backend   = k
  } if lookup(umig, "id", null) == null] }
  new_umigs = flatten([for k, umigs in local.umigs_without_ids : [for umig in coalesce(umigs, []) : merge(umig, {
    key = "${umig.zone}-${umig.name}"
  }) if length(umig.instances) > 0]])
  umig_ids = { for k, backend in var.backends : k => concat(
    [for umig in local.umigs_with_ids[k] : umig.id],
    [for umig in local.umigs_without_ids[k] : umig.id],
  ) }
  instance_groups = { for k, backend in var.backends : k => {
    port_name   = coalesce(backend.port_name, backend.port, 80) == 80 ? "http" : "${k}-${coalesce(backend.port, 80)}"
    port_number = coalesce(backend.port, local.http_port)
    ids         = concat(local.umig_ids[k])
    #flatten([for ig in coalesce(backend.instance_groups, []) : lookup(ig, "id", [])]),
    #flatten([for umig in coalesce(backend.umigs, []) : lookup(umig, "id", [])]),
    #[for umig in local.umigs_with_ids[k] : umig.id],
    #[for umig in local.umigs_without_ids[k] : umig.id]
    #[for umig in local.new_umigs[k] : umig.id],
    #length(local.new_umigs) > 0 ? google_compute_instance_group.default[*].id : null,
    #[],
    #)))
  } if length(coalesce(backend.instance_groups, [])) > 0 || length(coalesce(backend.umigs, [])) > 0 }
  # If instances were provided, we'll create an unmanaged instance group for them
  #new_umigs = flatten([for k, umigs in local.umigs : [for ig in umigs : ig if length(ig.instances) > 0]])
}

# Create new UMIGs if required
resource "google_compute_instance_group" "default" {
  for_each  = { for umig in local.new_umigs : "${umig.key}" => umig }
  project   = var.project_id
  name      = each.value.name
  network   = local.network
  instances = formatlist("${local.zones_prefix}/${each.value.zone}/instances/%s", each.value.instances)
  zone      = each.value.zone
}

# Create Named port for HTTP(S) load balancers
locals {
  named_ports = flatten([for k, v in local.instance_groups : [for group in v.ids : {
    key   = "${k}-${element(split("/", group), 5)}-${v.port_name}-${v.port_number}"
    group = group
    name  = v.port_name
    port  = v.port_number
  }] if local.is_http])
}
resource "google_compute_instance_group_named_port" "default" {
  for_each   = { for named_port in local.named_ports : "${named_port.key}" => named_port }
  project    = var.project_id
  group      = each.value.group
  name       = each.value.name
  port       = each.value.port
  depends_on = [google_compute_instance_group.default]
}