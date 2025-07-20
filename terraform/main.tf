provider "google" {
  project = var.project_id
  region  = "asia-northeast1"
}

# 有効化したいAPIのリストを定義
locals {
  enabled_apis = toset([
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "storage.googleapis.com",
    "artifactregistry.googleapis.com"
  ])
}

# for_each を使ってAPIをまとめて有効化
resource "google_project_service" "apis" {
  for_each = local.enabled_apis

  service = each.key

  # terraform destroy 実行時にAPIを無効化しないように設定
  disable_on_destroy = false
}

# VPCネットワークの作成
resource "google_compute_network" "vpc_network" {
  name                    = "wiz-exercise-vpc"
  auto_create_subnetworks = false
}

# GKEクラスタ用のプライベートサブネット
# 要件: Kubernetesクラスタはプライベートサブネットにデプロイする [cite: 63]
resource "google_compute_subnetwork" "private_subnet" {
  name          = "gke-private-subnet"
  ip_cidr_range = "10.0.1.0/24"
  network       = google_compute_network.vpc_network.id
  region        = var.region
  private_ip_google_access = true # プライベートノードがGoogle APIにアクセスできるようにする
    # GKEが使用するPodとServiceのIPアドレス範囲を定義する
  secondary_ip_range {
    range_name    = "gke-pod-range"
    ip_cidr_range = "10.10.0.0/16" # 例: Pod用のIP範囲
  }
  secondary_ip_range {
    range_name    = "gke-service-range"
    ip_cidr_range = "10.20.0.0/20" # 例: Service用のIP範囲
  }
}

# MongoDB VM用のパブリックサブネット
# 図ではPublic SubnetにVMが配置されている [cite: 27]
resource "google_compute_subnetwork" "public_subnet" {
  name          = "mongodb-public-subnet"
  ip_cidr_range = "10.0.2.0/24"
  network       = google_compute_network.vpc_network.id
  region        = var.region
}

# プライベートサブネットからインターネットへのアウトバウンド通信を許可するCloud NAT
resource "google_compute_router" "router" {
  name    = "gke-nat-router"
  network = google_compute_network.vpc_network.id
  region  = var.region
}

resource "google_compute_router_nat" "nat" {
  name                               = "gke-cloud-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetwork {
    name                    = google_compute_subnetwork.private_subnet.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
   nat_ip_allocate_option = "AUTO_ONLY"
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# --- ファイアウォールルール ---

# 要件: SSHはパブリックインターネットに公開する [cite: 53]
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh-public"
  network = google_compute_network.vpc_network.id
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["mongodb-server"]
}

# 要件: (MongoDBへの)アクセスはKubernetesネットワークからのみに制限する [cite: 55]
resource "google_compute_firewall" "allow_mongo_from_k8s" {
  name    = "allow-mongo-from-k8s"
  network = google_compute_network.vpc_network.id
  allow {
    protocol = "tcp"
    ports    = ["27017"]
  }
  source_tags = ["gke-node"]
  target_tags = ["mongodb-server"]
}

# GKEのコントロールプレーンからノードへのアクセスを許可
resource "google_compute_firewall" "allow_gke_control_plane" {
  name    = "allow-gke-control-plane"
  network = google_compute_network.vpc_network.id
  allow {
    protocol = "tcp"
    ports    = ["443", "10250"]
  }
  # GKEクラスタのコントロールプレーンのCIDRブロックを自動で取得
  source_ranges = [google_container_cluster.primary.private_cluster_config[0].master_ipv4_cidr_block]
  target_tags   = ["gke-node"]
}

# --- Cloud Storage ---

# 要件: オブジェクトストレージはパブリック読み取りとパブリックリストを許可する [cite: 57]
# 要件: データベースは毎日クラウドオブジェクトストレージにバックアップされる [cite: 56]
resource "google_storage_bucket" "backup_bucket" {
  name          = var.storage_bucket_name
  location      = "ASIA-NORTHEAST1"
  force_destroy = true # 演習用にバケットの削除を容易にする

  uniform_bucket_level_access = true
}

# allUsersに読み取り権限を付与
resource "google_storage_bucket_iam_member" "public_read_access" {
  bucket = google_storage_bucket.backup_bucket.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# Dockerイメージを保存するリポジトリを作成
resource "google_artifact_registry_repository" "my_app_repo" {
  # APIが有効になった後に作成されるように依存関係を設定
  depends_on = [google_project_service.artifactregistry]

  location      = "asia-northeast1" # リージョンはご自身の環境に合わせてください
  repository_id = "tech-exercise-repo" # リポジトリの名前
  description   = "Docker repository for the Wiz tech exercise"
  format        = "DOCKER" # 保存するフォーマットを指定
}