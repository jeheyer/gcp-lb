locals {
  ig_prefix = "projects/${var.project_id}/zones"
  umigs = { for k, v in var.backends : k => [for ig in coalesce(v.instance_groups, []) : {
    name      = try(coalesce(ig.name, ig.zone != null ? "${local.name_prefix}-${k}-${ig.zone}}" : null), null)
    zone      = ig.zone
    instances = coalesce(ig.instances, [])
  } if ig.id == null] }
  # If instances were provided, we'll create an unmanaged instance group for them
  new_umigs = flatten([for k, umigs in local.umigs : [for ig in umigs : {
    id        = "${local.ig_prefix}/${ig.zone}/instanceGroups/${ig.name}"
    name      = ig.name
    zone      = ig.zone
    instances = ig.instances
    backend   = k
  } if length(ig.instances) > 0]])
}

resource "google_compute_instance_group" "default" {
  count     = length(local.new_umigs)
  project   = var.project_id
  name      = local.new_umigs[count.index].name
  network   = "projects/${local.network_project_id}/global/networks/${var.network_name}"
  instances = formatlist("${local.ig_prefix}/${local.new_umigs[count.index].zone}/instances/%s", local.new_umigs[count.index].instances)
  zone      = local.new_umigs[count.index].zone
}

locals {
  instance_groups = { for k, v in var.backends : k => {
    ids = flatten([for ig in v.instance_groups : coalesce(
      ig.id,
      try("${local.ig_prefix}/${ig.zone}/instanceGroups/${ig.name}", null),
      )
    ])
  } if length(coalesce(v.instance_groups, [])) > 0 }
}