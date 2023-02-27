locals {
  /*
  snegs = { for k, v in var.backends : k => {
    type   = "sneg"
    name   = coalesce(v.cloud_run_name, k)
    region = coalesce(v.region, local.region)
    image = try(coalesce(
      v.docker_image == null ? null : "docker.io/${v.docker_image}",
      v.container_image == null ? null : length(split("/", v.container_image)) > 1 ? v.container_image : "gcr.io/${var.project_id}/${v.container_image}",
    ), null)
    port       = coalesce(v.container_port, v.port, 80)
    psc_target = v.psc_target
  } if try(coalesce(v.cloud_run_name, v.container_image, v.docker_image, v.container_port, v.psc_target), null) != null }
  */
  snegs = { for k, v in var.backends : k => {
    ids = [for ig in v.instance_groups : coalesce(
      ig.id, try("${local.ig_prefix}/${ig.zone}/instanceGroups/${ig.name}", null)
    )]

    #type   = "sneg"
    name   = coalesce(v.snegs.cloud_run_name, v.snegs.app_engine_name, k)
    region = coalesce(v.region, local.region)
    image = try(coalesce(
      v.snegs.docker_image == null ? null : "docker.io/${v.snegs.docker_image}",
      v.snegs.container_image == null ? null : length(split("/", v.snegs.container_image)) > 1 ? v.snegs.container_image : "gcr.io/${var.project_id}/${v.snegs.container_image}",
    ), null)
    port       = coalesce(v.snegs.container_port, v.port, 80)
    psc_target = v.psc_target
  } if length(coalesce(v.snegs, [])) > 0 }
  cloud_runs = { for k, v in local.snegs : k => v if v.image != null }
}

# Cloud Run Services
resource "google_cloud_run_service" "default" {
  for_each = local.cloud_runs
  project  = var.project_id
  name     = each.value.name
  location = each.value.region
  template {
    spec {
      containers {
        image = each.value.image
        ports {
          name           = "http1"
          container_port = each.value.port
        }
      }
    }
  }
  traffic {
    percent         = 100
    latest_revision = true
  }
}

# Enable unauthenticated access to cloud Run, if set to true
resource "google_cloud_run_service_iam_member" "default" {
  for_each = { for k, v in local.cloud_runs : k => v if coalesce(v.allow_unauthenticated, false) }
  project  = var.project_id
  service  = google_cloud_run_service.default[each.key].name
  location = google_cloud_run_service.default[each.key].location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Serverless Network Endpoint Group 
resource "google_compute_region_network_endpoint_group" "default" {
  for_each              = local.snegs
  project               = var.project_id
  name                  = each.value.name
  network_endpoint_type = each.value.psc_target != null ? "PRIVATE_SERVICE_CONNECT" : "SERVERLESS"
  region                = each.value.region
  psc_target_service    = each.value.psc_target
  dynamic "cloud_run" {
    for_each = each.value.image != null ? [true] : []
    content {
      service = google_cloud_run_service.default[each.key].name
    }
  }
}

