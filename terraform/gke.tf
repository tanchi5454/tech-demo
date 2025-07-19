# GKEクラスタ用のサービスアカウント
resource "google_service_account" "gke_sa" {
  account_id   = "gke-sa"
  display_name = "Service Account for GKE Nodes"
}

# GKEクラスタ
resource "google_container_cluster" "primary" {
  name     = var.gke_cluster_name
  location = var.zone
  network    = google_compute_network.vpc_network.id
  subnetwork = google_compute_subnetwork.private_subnet.id
  initial_node_count = 1
  
  # プライベートクラスタの設定
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false # デモのためにパブリックエンドポイントを有効化
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }
  
  # PodとServiceのIPレンジ
  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-pod-range"
    services_secondary_range_name = "gke-service-range"
  }

  # コントロールプレーンの監査ログを有効化
  # 要件: CSP環境のコントロールプレーン監査ロギングを設定する必要があります [cite: 85]
  master_authorized_networks_config {}
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }
  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }
  
  # GKEが作成するリソースを削除するために必要
  remove_default_node_pool = true
}

# GKEノードプール
resource "google_container_node_pool" "primary_nodes" {
  name       = "${google_container_cluster.primary.name}-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    machine_type = "e2-medium"
    tags         = ["gke-node"]
    service_account = google_service_account.gke_sa.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}