# gke.tf

# GKEクラスタ
resource "google_container_cluster" "primary" {
  name     = "wiz-gke-cluster"
  location = var.region
  network  = google_compute_network.wiz_vpc.id
  subnetwork = google_compute_subnetwork.private_subnet.id

  initial_node_count = var.gke_num_nodes

  # デフォルトノードプールを無効化 
  remove_default_node_pool = true


  // プライベートクラスタ設定
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false // コントロールプレーンはパブリックアクセス可能
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }
  
  // コントロールプレーンがノードと通信できるように許可
  master_authorized_networks_config {}

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  release_channel {
    channel = "REGULAR"
  }
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "default-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = var.gke_num_nodes

  node_config {
    machine_type = "e2-medium"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}