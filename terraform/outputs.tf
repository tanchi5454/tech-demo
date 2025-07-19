output "mongodb_vm_public_ip" {
  description = "Public IP address of the MongoDB VM."
  value       = google_compute_instance.mongodb_server.network_interface[0].access_config[0].nat_ip
}

output "storage_bucket_name" {
  description = "Name of the GCS bucket for backups."
  value       = google_storage_bucket.backup_bucket.name
}

output "gke_cluster_name" {
  description = "GKE cluster name."
  value       = google_container_cluster.primary.name
}

output "get_gke_credentials_command" {
  description = "Command to get kubectl credentials for the GKE cluster."
  value = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone ${var.zone} --project ${var.project_id}"
}

output "mongodb_internal_ip" {
  description = "Internal IP of the MongoDB VM for the application to connect to."
  value = google_compute_instance.mongodb_server.network_interface[0].network_ip
}