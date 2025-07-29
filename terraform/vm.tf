# vm.tf

# --- VMとサービスアカウントの設定 ---

# MongoDB VMに割り当てるサービスアカウント
resource "google_service_account" "mongodb_vm_sa" {
  account_id   = "mongodb-vm-sa"
  display_name = "Service Account for MongoDB VM"
}

# サービスアカウントに過剰な権限を付与（要件）
resource "google_project_iam_member" "vm_iam_compute" {
  project = var.project_id
  role    = "roles/compute.admin" // VM作成などが可能な強い権限
  member  = "serviceAccount:${google_service_account.mongodb_vm_sa.email}"
}
# サービスアカウントにLogging Writer の権限を付与
resource "google_project_iam_member" "logging_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  =  "serviceAccount:${google_service_account.mongodb_vm_sa.email}"
}

# サービスアカウントにSecret Managerへのアクセス権を付与
resource "google_project_iam_member" "vm_iam_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.mongodb_vm_sa.email}"
}

# 既に手動で作成したサービスアカウントをデータソースとして参照
data "google_service_account" "github_actions_sa" {
  account_id = "iac-operations-sa"
}

# GitHub ActionsのサービスアカウントにSecret Managerへのアクセス権を付与
resource "google_project_iam_member" "github_actions_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${data.google_service_account.github_actions_sa.email}"
}

# MongoDB用のVMインスタンス
resource "google_compute_instance" "mongodb_vm" {
  name         = "mongodb-vm"
  machine_type = "e2-medium"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = var.outdated_linux_image // 要件: 古いOS
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.public_subnet.id
    access_config {
      // パブリックIPを自動的に割り当て
    }
  }

  service_account {
    email  = google_service_account.mongodb_vm_sa.email
    scopes = ["cloud-platform"]
  }

  # 起動スクリプトでSecret Managerから認証情報を取得
  metadata = {
    # file() 関数で外部スクリプトファイルを指定
    startup-script = file("startup-script.sh")
  }

  tags = ["mongodb-vm"]

}