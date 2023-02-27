locals {
  backend_buckets = { for k, v in var.backends : k => {
    type        = "bucket"
    bucket_name = coalesce(v.bucket_name, k)
    description = coalesce(v.description, "Backend Bucket '${k}'")
    enable_cdn  = coalesce(v.enable_cdn, true) # This is probably static content, and GCP CDN is cheap, so why not?
  } if v.type == "bucket" || v.bucket_name != null && local.is_http && startswith(local.lb_scheme, "EXTERNAL") }
}

# Backend Buckets
resource "google_compute_backend_bucket" "default" {
  for_each    = local.backend_buckets
  project     = var.project_id
  name        = "${local.name_prefix}-${each.value.bucket_name}"
  bucket_name = each.value.bucket_name
  description = each.value.description
  enable_cdn  = each.value.enable_cdn
}
