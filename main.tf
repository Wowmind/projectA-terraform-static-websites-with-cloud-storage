# create a bucket for the website

resource "google_storage_bucket" "website" {
  name = "my-web-info-site"
  location = var.region
  force_destroy = true
  
  website {
    main_page_suffix = "index.html"
    not_found_page = "404.html"
  }
}


# upload the index.html to the bucket
resource "google_storage_bucket_object" "index-html" {
  name = "index-web-page-inf0"
  bucket = google_storage_bucket.website.name

  source = "C:/Program Files/project-1/websites/index.html"
}

# upload the 404.html to the bucket

resource "google_storage_bucket_object" "static-404-html" {
  name = "404"
  bucket = google_storage_bucket.website.name

  source = "C:/Program Files/project-1/websites/404.html"
}

# create a object publicly accessible
resource "google_storage_bucket_iam_binding" "public_access" {
  bucket = google_storage_bucket.website.name
  role = "roles/storage.objectViewer"

  members = [ "allUsers" ]
}

# Reserve an external IP
resource "google_compute_global_address" "website" {
  provider = google
  name     = "my-ip"
}
# Get the managed DNS zone
data "google_dns_managed_zone" "gcp_cloudstore" {
  provider = google
  name     = "cloudstore"
}

# Add the IP to the DNS
resource "google_dns_record_set" "website" {
  provider     = google
  name         = "website.${data.google_dns_managed_zone.gcp_cloudstore.dns_name}"
  type         = "A"
  ttl          = 300
  managed_zone = data.google_dns_managed_zone.gcp_cloudstore.name
  rrdatas      = [google_compute_global_address.website.address]
}

# Add the bucket as a CDN backend
resource "google_compute_backend_bucket" "website-backend" {
  provider    = google
  name        = "website-backend"
  description = "Contains files needed by the website"
  bucket_name = google_storage_bucket.website.name
  enable_cdn  = true
}

# Create HTTPS certificate
resource "google_compute_managed_ssl_certificate" "website" {
  provider = google
  name     = "website-cert"
  managed {
    domains = [google_dns_record_set.website.name]
  }
}

# GCP URL MAP
resource "google_compute_url_map" "website" {
  provider        = google
  name            = "website-url-map"
  default_service = google_compute_backend_bucket.website-backend.self_link
    host_rule {
    hosts        = ["*"]
    path_matcher = "allpaths"
  }

  path_matcher {
    name            = "allpaths"
    default_service = google_compute_backend_bucket.website-backend.self_link
  }
}

# GCP target proxy
resource "google_compute_target_https_proxy" "website" {
  provider         = google
  name             = "website-target-proxy"
  url_map          = google_compute_url_map.website.self_link
  ssl_certificates = [google_compute_managed_ssl_certificate.website.self_link]
}

# GCP forwarding rule
resource "google_compute_global_forwarding_rule" "default" {
  provider              = google
  name                  = "website-forwarding-rule"
  load_balancing_scheme = "EXTERNAL"
  ip_address            = google_compute_global_address.website.address
  ip_protocol           = "TCP"
  port_range            = "443"
  target                = google_compute_target_https_proxy.website.self_link
}