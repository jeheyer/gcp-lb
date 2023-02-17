output "address" {
  value = local.is_global && var.enable_ipv4 ? google_compute_global_address.default["ipv4"].address : null
  #one(google_compute_address.default).address
}
output "ipv4_address" {
  value = local.is_global && var.enable_ipv4 ? google_compute_global_address.default["ipv4"].address : null
  #one(google_compute_address.default).address
}
output "ipv6_address" {
  value = local.is_global && var.enable_ipv6 ? google_compute_global_address.default["ipv6"].address : null
}
output "backends" {
  value = {
    for k, v in merge(local.backend_services, local.backend_buckets) : k => {
      type     = v.type
      region   = coalesce(v.region, "global")
      protocol = v.protocol
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
