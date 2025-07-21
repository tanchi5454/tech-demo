# vm.tf

# --- Secret Managerで管理する機密情報 ---

# ユーザー名用のSecret
resource "google_secret_manager_secret" "mongodb_user" {
  project   = var.project_id
  secret_id = "mongodb-user"
  replication {
   auto {}
  }
}
resource "google_secret_manager_secret_version" "mongodb_user_version" {
  secret      = google_secret_manager_secret.mongodb_user.id
  secret_data = "wizadmin"
}

# パスワード用のSecret
resource "google_secret_manager_secret" "mongodb_password" {
  project   = var.project_id
  secret_id = "mongodb-password"
  replication {
   auto {}
  }
}
resource "google_secret_manager_secret_version" "mongodb_password_version" {
  secret      = google_secret_manager_secret.mongodb_password.id
  secret_data = "070125Shtano!" # ★★★ 必ず強力なパスワードに変更 ★★★
}

#  JWTトークン用のSecret Key
resource "google_secret_manager_secret" "jwt_secret_key" {
  project   = var.project_id
  secret_id = "jwt-secret-key"
  replication {
   auto {}
  }
}
resource "google_secret_manager_secret_version" "jwt_secret_key_version" {
  secret      = google_secret_manager_secret.jwt_secret_key.id
  secret_data = "070125Shtano!" # ★★★ 必ずランダムな文字列に変更 ★★★
}

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

# サービスアカウントにSecret Managerへのアクセス権を付与 
resource "google_project_iam_member" "vm_iam_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.mongodb_vm_sa.email}"
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
  metadata_startup_script = <<-EOF
    #!/bin/bash
    set -e
    set -u

    # MongoDB 4.4 (古いバージョン) のインストール
    apt-get update
    apt-get install -y gnupg wget
    wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add -
    echo "deb http://repo.mongodb.org/apt/debian bullseye/mongodb-org/4.4 main" | tee /etc/apt/sources.list.d/mongodb-org-4.4.list
    apt-get update
    apt-get install -y mongodb-org=4.4.6 mongodb-org-server=4.4.6 mongodb-org-shell=4.4.6 mongodb-org-mongos=4.4.6 mongodb-org-tools=4.4.6

    # IPバインディングを 0.0.0.0 に変更
    sed -i "s/bindIp: 127.0.0.1/bindIp: 0.0.0.0/" /etc/mongod.conf
    
    # 認証を有効にする
    echo -e "\nsecurity:\n  authorization: enabled" >> /etc/mongod.conf
    
    systemctl restart mongod
    systemctl enable mongod

    # Secret Managerから認証情報を取得
    MONGO_USER=$(gcloud secrets versions access latest --secret="mongodb-user" --project="${var.project_id}")
    MONGO_PASS=$(gcloud secrets versions access latest --secret="mongodb-password" --project="${var.project_id}")

    # 取得した認証情報でDBユーザーを作成
    sleep 10
    mongo --eval "db.getSiblingDB('admin').createUser({user: '\$MONGO_USER', pwd: '\$MONGO_PASS', roles: [{role: 'readWriteAnyDatabase', db: 'admin'}]})"

    # バックアップスクリプトの作成（認証情報を使用するよう更新）
    cat <<EOT > /usr/local/bin/backup-mongo.sh
#!/bin/bash
BACKUP_DIR="/var/backups/mongodb"
TIMESTAMP=\$(date +"%Y%m%d%H%M")
BACKUP_NAME="mongodb-backup-\$TIMESTAMP"
BUCKET_NAME="${google_storage_bucket.db_backups.name}"

mkdir -p \$BACKUP_DIR
mongodump --out \$BACKUP_DIR/\$BACKUP_NAME --authenticationDatabase admin -u "\$MONGO_USER" -p "\$MONGO_PASS"
tar -czvf \$BACKUP_DIR/\$BACKUP_NAME.tar.gz -C \$BACKUP_DIR \$BACKUP_NAME
    
gsutil cp \$BACKUP_DIR/\$BACKUP_NAME.tar.gz gs://\$BUCKET_NAME/

rm -rf \$BACKUP_DIR/*
EOT
    chmod +x /usr/local/bin/backup-mongo.sh

    # cronジョブの作成
    (crontab -l 2>/dev/null; echo "0 3 * * * /usr/local/bin/backup-mongo.sh") | crontab -
  EOF

  tags = ["mongodb-server"]
  
  # TerraformがSecretの作成を待ってからVMを作成するように依存関係を明示
  depends_on = [
    google_secret_manager_secret_version.mongodb_user_version,
    google_secret_manager_secret_version.mongodb_password_version,
    google_secret_manager_secret_version.jwt_secret_key_version,
  ]
}