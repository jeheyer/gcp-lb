variable "project_id" {
  description = "GCP Project ID"
  type        = string
}
variable "name_prefix" {
  description = "Name Prefix for this Load Balancer"
  type        = string
  default     = null
  validation {
    condition     = var.name_prefix != null ? length(var.name_prefix) < 50 : true
    error_message = "Name Prefix cannot exceed 49 characters."
  }
}
variable "description" {
  description = "Description for this Load Balancer"
  type        = string
  default     = null
  validation {
    condition     = var.description != null ? length(var.description) < 256 : true
    error_message = "Description cannot exceed 255 characters."
  }
}
variable "classic" {
  description = "Create Classic Load Balancer (or instead use envoy-based platform)"
  type        = bool
  default     = false
}
variable "region" {
  description = "GCP Region Name (regional LB only)"
  type        = string
  default     = null
}
variable "ssl_policy_name" {
  description = "Name of pre-existing SSL Policy to Use for Frontend"
  type        = string
  default     = null
}
variable "tls_profile" {
  description = "If creating SSL profile, the Browser Profile to use"
  type        = string
  default     = null
}
variable "min_tls_version" {
  description = "If creating SSL profile, the Minimum TLS Version to allow"
  type        = string
  default     = null
}
variable "ssl_certs" {
  description = "Map of SSL Certificates to upload to Google Certificate Manager"
  type = map(object({
    certificate = string
    private_key = string
    description = optional(string)
  }))
  default = null
}
variable "ssl_cert_names" {
  description = "List of existing SSL certificates to apply to this load balancer frontend"
  type        = list(string)
  default     = null
}
variable "use_gmc" {
  description = "Use Google-Managed Certs"
  type        = bool
  default     = false
}
variable "use_ssc" {
  description = "Use Self-Signed Certs"
  type        = bool
  default     = null
}
variable "domains" {
  type    = list(string)
  default = null
}
variable "key_algorithm" {
  description = "For self-signed cert, the Algorithm for the Private Key"
  type        = string
  default     = "RSA"
}
variable "key_bits" {
  description = "For self-signed cert, the number for bits for the private key"
  type        = number
  default     = 2048
}
variable "default_service_id" {
  type    = string
  default = null
}
variable "network_name" {
  type    = string
  default = null
}
variable "subnet_name" {
  type    = string
  default = null
}
variable "network_project_id" {
  type    = string
  default = null
}
variable "type" {
  type    = string
  default = null
}
variable "enable_ipv4" {
  type    = bool
  default = true
}
variable "enable_ipv6" {
  type    = bool
  default = false
}
variable "ipv4_address" {
  type    = string
  default = null
}
variable "ipv6_address" {
  type    = string
  default = null
}
variable "ip_address" {
  type    = string
  default = null
}
variable "port_range" {
  type    = string
  default = null
}
variable "ports" {
  type    = list(number)
  default = null
}
variable "all_ports" {
  type    = bool
  default = false
}
variable "http_port" {
  description = "HTTP port for LB Frontend"
  type        = number
  default     = 80
}
variable "https_port" {
  description = "HTTPS port for LB Frontend"
  type        = number
  default     = 443
}
variable "global_access" {
  type    = bool
  default = false
}
variable "backend_timeout" {
  description = "Default timeout for all backends in seconds (can be overridden)"
  type        = number
  default     = 30
}
variable "default_backend" {
  description = "Default backend"
  type        = string
  default     = null
}
variable "routing_rules" {
  description = "Route rules to send different hostnames/paths to different backends"
  type = map(object({
    hosts   = list(string)
    backend = optional(string)
    path_rules = optional(list(object({
      paths   = list(string)
      backend = string
    })))
  }))
  default = {}
}
variable "backends" {
  description = "Map of all backend services & buckets"
  type = map(object({
    type              = optional(string) # We'll try and figure it out automatically
    description       = optional(string)
    region            = optional(string)
    bucket_name       = optional(string)
    psc_target        = optional(string)
    port              = optional(number)
    port_name         = optional(string)
    protocol          = optional(string)
    enable_cdn        = optional(bool)
    cdn_cache_mode    = optional(string)
    timeout           = optional(number)
    logging           = optional(bool)
    logging_rate      = optional(number)
    affinity_type     = optional(string)
    cloudarmor_policy = optional(string)
    healthchecks = optional(list(object({
      id     = optional(string)
      name   = optional(string)
      region = optional(string)
    })))
    instance_groups = optional(list(object({
      id        = optional(string)
      name      = optional(string)
      zone      = optional(string)
      instances = optional(list(string))
    })))
    snegs = optional(list(object({
      region                = optional(string)
      cloud_run_name        = optional(string) # Cloud run service name
      container_image       = optional(string) # Default to GCR if not full URL
      docker_image          = optional(string) # Pulls image from docker.io
      container_port        = optional(number) # Cloud run container port
      allow_unauthenticated = optional(bool)
    })))
    ineg = optional(object({
      fqdn       = optional(string)
      ip_address = optional(string)
      port       = optional(number)
    }))
    capacity_scaler       = optional(number)
    max_utilization       = optional(number)
    max_rate_per_instance = optional(number)
    max_connections       = optional(number)
  }))
  default = {}
  validation {
    condition     = alltrue([for k, v in var.backends : length(k) < 32 ? true : false])
    error_message = "Backend key values must be under 32 characters."
  }

}
