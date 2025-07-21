# outputs.tf

output "gke_cluster_name" {
  description = "The name of the GKE cluster."
  value       = google_container_cluster.primary.name
}

output "gke_cluster_endpoint" {
  description = "The endpoint of the GKE cluster."
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "mongodb_vm_external_ip" {
  description = "The external IP address of the MongoDB VM."
  value       = google_compute_instance.mongodb_vm.network_interface[0].access_config[0].nat_ip
}

output "mongodb_vm_internal_ip" {
  description = "The internal IP address of the MongoDB VM."
  value       = google_compute_instance.mongodb_vm.network_interface[0].network_ip
}

output "db_backup_bucket_name" {
  description = "The name of the GCS bucket for database backups."
  value       = google_storage_bucket.db_backups.name
}