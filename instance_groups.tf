locals {
  ig_prefix = "projects/${var.project_id}/zones"
  instance_groups = { for k, v in var.backends : k => {
    #type = "instance_groups"
    ids = [for ig in v.instance_groups : coalesce(
      ig.id, try("${local.ig_prefix}/${ig.zone}/instanceGroups/${ig.name}", null)
    )]
  } if length(coalesce(v.instance_groups, [])) > 0 }
}
