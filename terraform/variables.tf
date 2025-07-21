# variables.tf

variable "project_id" {
  description = "The Google Cloud project ID to deploy resources into."
  type        = string
}

variable "region" {
  description = "The GCP region to deploy resources into."
  type        = string
  default     = "asia-northeast1" // 東京リージョン
}

variable "zone" {
  description = "The GCP zone to deploy resources into."
  type        = string
  default     = "asia-northeast1-a"
}

variable "gke_num_nodes" {
  description = "The number of nodes in the GKE cluster."
  type        = number
  default     = 1
}

variable "outdated_linux_image" {
  description = "An outdated Linux image for the MongoDB VM (Debian 10)."
  type        = string
  default     = "debian-cloud/debian-11"
}