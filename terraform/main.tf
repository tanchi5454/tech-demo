# main.tf

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.50.0"
    }
  }

  // Terraformの状態を管理するGCSバケットを指定
  // このバケットは事前に手動で作成
  backend "gcs" {
    bucket = "techdemo-01-terraform-state" #一意の名前に変更
    prefix = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

// カスタムVPCの作成
resource "google_compute_network" "wiz_vpc" {
  name                    = "wiz-vpc"
  auto_create_subnetworks = false
}

// GKEクラスタ用のプライベートサブネット
resource "google_compute_subnetwork" "private_subnet" {
  name          = "private-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.wiz_vpc.id
}

// MongoDB VM用のパブリックサブネット
resource "google_compute_subnetwork" "public_subnet" {
  name          = "public-subnet"
  ip_cidr_range = "10.0.2.0/24"
  region        = var.region
  network       = google_compute_network.wiz_vpc.id
}

// Cloud NATのルーター（プライベートサブネットからのアウトバウンド通信用）
resource "google_compute_router" "router" {
  name    = "wiz-nat-router"
  network = google_compute_network.wiz_vpc.id
  region  = var.region
}

// Cloud NATゲートウェイの設定
resource "google_compute_router_nat" "nat" {
  name                               = "wiz-nat-gateway"
  router                             = google_compute_router.router.name
  region                             = var.region
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
  subnetwork {
    name                    = google_compute_subnetwork.private_subnet.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

// ファイアウォールルール
resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal"
  network = google_compute_network.wiz_vpc.name
  allow {
    protocol = "all"
  }
  source_ranges = ["10.0.1.0/24", "10.0.2.0/24"]
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = google_compute_network.wiz_vpc.name
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["0.0.0.0/0"] // 要件: インターネットからのSSHを許可
}

// DBバックアップ用のGCSバケット
resource "google_storage_bucket" "db_backups" {
  name          = "${var.project_id}-db-backups"
  location      = var.region
  force_destroy = true // デモ環境のクリーンアップを容易にするため

  uniform_bucket_level_access = true
}

// バケットをパブリックに読み取り可能にするIAM設定
resource "google_storage_bucket_iam_member" "public_reader" {
  bucket = google_storage_bucket.db_backups.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}