variable "project_id" {
  type        = string
  description = "The GCP project ID to deploy to."
}

variable "region" {
  description = "The GCP region to deploy resources into."
  type        = string
  default     = "asia-northeast1"
}

variable "zone" {
  description = "The GCP zone to deploy resources into."
  type        = string
  default     = "asia-northeast1-a"
}

variable "gke_cluster_name" {
  description = "The name for the GKE cluster."
  type        = string
  default     = "wiz-exercise-cluster"
}

variable "mongo_vm_name" {
  description = "The name for the MongoDB VM."
  type        = string
  default     = "mongodb-server"
}

variable "storage_bucket_name" {
  description = "The name for the GCS backup bucket. Must be globally unique."
  type        = string
  default     = "shtano-tech-exercise-466314" # 必ず一意な名前に変更してください
}