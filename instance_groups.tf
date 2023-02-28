locals {
  ig_prefix = "projects/${var.project_id}/zones"
  umigs = { for k, v in var.backends : k => [for ig in coalesce(v.instance_groups, []) : {
    name      = ig.name
    zone      = ig.zone
    instances = coalesce(ig.instances, [])
    id        = coalesce(ig.id, "${local.ig_prefix}/${ig.zone}/instanceGroups/${ig.name}")
    backend   = k
  } if ig.id == null] }
  instance_groups = { for k, v in var.backends : k => {
    port_name   = coalesce(v.port_name, v.port == 80 ? "http" : "${k}-${v.port}")
    port_number = coalesce(v.port, local.http_port)
    ids = concat(
      flatten([for ig in v.instance_groups : ig.id if ig.id != null]),
      [for ig in local.umigs[k] : ig.id],
    )
  } if length(coalesce(v.instance_groups, [])) > 0 }
  # If instances were provided, we'll create an unmanaged instance group for them
  new_umigs = flatten([for k, umigs in local.umigs : [for ig in umigs : ig if length(ig.instances) > 0]])
}

resource "google_compute_instance_group" "default" {
  count     = 0 #length(local.new_umigs)
  project   = var.project_id
  name      = local.new_umigs[count.index].name
  network   = "projects/${local.network_project_id}/global/networks/${var.network_name}"
  instances = formatlist("${local.ig_prefix}/${local.new_umigs[count.index].zone}/instances/%s", local.new_umigs[count.index].instances)
  zone      = local.new_umigs[count.index].zone
}

# Create Named port for HTTP(S) load balancers
locals {
  named_ports = { for k, igs in local.instance_groups : k => [for ig_id in igs.ids : {
    key         = "${k}-${element(split("/", ig_id), 5)}-${igs.port_number}"
    ig_id       = ig_id
    port_name   = igs.port_name
    port_number = igs.port_number
    #backend = k
  } if igs.port_number != 80] if local.is_http }
}
/*
resource "google_compute_instance_group_named_port" "default" {
  for_each = { for k, igs in local.named_ports : [ for ig in flatten(igs) : ig.key => ig ] ]
  group = each.value.ig_id
  name  = each.value.port_name
  port  = each.value.port_number
} */