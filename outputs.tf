output "address" {
  value = local.is_global ? google_compute_global_address.default["ipv4"].address : google_compute_address.default["ipv4"].address
  #one(google_compute_address.default).address
}
output "ipv4_address" {
  value = var.enable_ipv4 ? (local.is_global ? google_compute_global_address.default["ipv4"].address : google_compute_address.default["ipv4"].address) : null
  #one(google_compute_address.default).address
}
output "ipv6_address" {
  value = var.enable_ipv6 && local.is_global ? google_compute_global_address.default["ipv6"].address : null
}
output "backends" {
  value = {
    for k, v in merge(local.backend_services, local.backend_buckets) : k => {
      type     = v.type
      region   = coalesce(lookup(v, "region", null), "global")
      protocol = lookup(v, "protocol", null)
      groups   = lookup(v, "groups", [])
    }
  }
}
output "name" { value = local.name_prefix }
output "type" { value = local.type }
output "is_global" { value = local.is_global }
output "is_regional" { value = local.is_regional }
output "is_classic" { value = local.is_classic }
output "is_internal" { value = local.is_internal }
output "is_http" { value = local.is_http }
output "lb_scheme" { value = local.lb_scheme }
output "psc" { value = local.psc }
