provider "google" {
    project = var.project_id
}
data "google_compute_network" "shared_vpc" {
  name    = var.google_compute_network
  project = var.project_id
}
resource "google_compute_global_address" "apigee_range1" {
  name          = var.google_compute_global_address
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = data.google_compute_network.shared_vpc.id
}
resource "google_service_networking_connection" "apigee_vpc_connection" {
  network                 =data.google_compute_network.shared_vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.apigee_range1.name]
}
locals {
    googleapis = [   "apigee.googleapis.com",
   "cloudkms.googleapis.com",
   "compute.googleapis.com",
   "servicenetworking.googleapis.com"
 ]
 }
resource "google_project_service" "apis" {
     for_each           = toset(local.googleapis)
     project            = var.project_id
     service            = each.key 
     disable_on_destroy = false
     }
resource "google_apigee_organization" "apigeex_org" { 
  analytics_region   = var.region
  project_id         = var.project_id
  authorized_network = data.google_compute_network.shared_vpc.id
  depends_on         = [
    google_service_networking_connection.apigee_vpc_connection,
    //google_project_service.apis.apigee,
  ]
}
resource "google_apigee_environment" "apigee_org_region_env1" {
  name         = var.google_apigee_environment
  description  = "apigee-env-dev"
  display_name = "apigee-env-dev"
  org_id       = google_apigee_organization.apigeex_org.id
}
resource "google_apigee_envgroup" "env_grp_dev1" {
  name      = var.google_apigee_envgroup
  hostnames = ["grp.test.com"]
  org_id    = google_apigee_organization.apigeex_org.id
}
resource "google_apigee_instance" "apigee_instance1" {
  name     = var.google_apigee_instance
  location = var.region
  org_id   = google_apigee_organization.apigeex_org.id
}
resource "google_apigee_instance_attachment" "apigee_instance_attachment1" {
  instance_id  = google_apigee_instance.apigee_instance1.id
  environment  = google_apigee_environment.apigee_org_region_env1.name
}
resource "google_compute_region_backend_service" "producer_service_backend1" {
  name          = var.google_compute_region_backend_service
  project       = var.project_id
  region        = var.region
  health_checks = [google_compute_health_check.producer_service_health_check1.id]
}
resource "google_compute_health_check" "producer_service_health_check1" {
  name                = var.google_compute_health_check
  project             = var.project_id
  check_interval_sec  = 1
  timeout_sec         = 1
  tcp_health_check {
    port = "80"
  }
}
resource "google_compute_forwarding_rule" "apigee_ilb_target_service1" {
   name                  = var.google_compute_forwarding_rule
   region                = var.region
   project               = var.project_id
   load_balancing_scheme = "INTERNAL"
   backend_service       = google_compute_region_backend_service.producer_service_backend1.id
   all_ports             = true
   network               = data.google_compute_network.shared_vpc.id
   //subnetwork            =    "projects/${google_compute_network.apigee_network.id}/regions/us-east1/subnetworks/prv-sn-1"
}
