# MongoDB VM用のサービスアカウント
# 要件: VMには過剰に寛容なCSP権限を付与する（例：VMを作成できる） [cite: 54]
resource "google_service_account" "mongo_vm_sa" {
  account_id   = "mongo-vm-sa"
  display_name = "Service Account for MongoDB VM"
}

resource "google_project_iam_member" "mongo_vm_sa_permissive_role" {
  project = var.project_id
  role    = "roles/compute.admin" # 過剰な権限
  member  = "serviceAccount:${google_service_account.mongo_vm_sa.email}"
}

# MongoDB VM
resource "google_compute_instance" "mongodb_server" {
  name         = var.mongo_vm_name
  machine_type = "e2-medium"
  zone         = var.zone
  tags         = ["mongodb-server"]

  boot_disk {
    initialize_params {
      # 要件: VMは1年以上古いバージョンのLinuxを利用する [cite: 52]
      # Debian 10 "Buster" は2019年リリース
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.public_subnet.id
    access_config {
      # パブリックIPを割り当て
    }
  }

  service_account {
    email  = google_service_account.mongo_vm_sa.email
    scopes = ["cloud-platform"]
  }

  # 起動スクリプト
  # 要件: データベースは1年以上古いDBバージョンであるMongoDBであること [cite: 55]
  # 要件: データベース認証を要求すること [cite: 55]
  # 要件: データベースは毎日自動でバックアップされること [cite: 56]
  metadata_startup_script = <<-EOF
    #!/bin/bash
    sudo apt-get update
    sudo apt-get install -y gnupg wget

    # --- Install MongoDB 4.4 (2020 release) ---
    wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
    echo "deb http://repo.mongodb.org/apt/debian bullseye/mongodb-org/4.4 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
    sudo apt-get update
    sudo apt-get install -y mongodb-org=4.4.6 mongodb-org-server=4.4.6 mongodb-org-shell=4.4.6 mongodb-org-mongos=4.4.6 mongodb-org-tools=4.4.6

    # --- Configure MongoDB ---
    # 外部からの接続を許可
    sudo sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/g' /etc/mongod.conf
    
    # 認証を有効化
    sudo sed -i '/security/a\  authorization: enabled' /etc/mongod.conf
    sudo systemctl start mongod
    sudo systemctl enable mongod

    # --- Create DB user ---
    # 実際のシナリオではパスワードは安全に管理する
    mongo <<EOM
    use admin
    db.createUser({
      user: "wizadmin",
      pwd: "WizPassword123!",
      roles: [{ role: "userAdminAnyDatabase", db: "admin" }, { role: "readWriteAnyDatabase", db: "admin" }]
    })
    use tododb
    db.createUser({
      user: "todoapp",
      pwd: "TodoPassword123!",
      roles: [{ role: "readWrite", db: "tododb" }]
    })
    EOM
    sudo systemctl restart mongod

    # --- Setup Backup ---
    sudo apt-get install -y google-cloud-sdk
    # Backup script
    echo '#!/bin/bash
    TIMESTAMP=$(date +"%Y%m%d%H%M")
    BACKUP_FILE="/tmp/mongodump-$TIMESTAMP"
    GCS_BUCKET="${google_storage_bucket.backup_bucket.name}"
    
    mongodump --username=wizadmin --password="WizPassword123!" --authenticationDatabase=admin --out=$BACKUP_FILE
    
    gcloud storage cp -r $BACKUP_FILE gs://$GCS_BUCKET/
    
    rm -rf $BACKUP_FILE
    ' | sudo tee /usr/local/bin/mongo_backup.sh

    sudo chmod +x /usr/local/bin/mongo_backup.sh

    # Cron job for daily backup
    (sudo crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/mongo_backup.sh") | sudo crontab -

  EOF
  
  # 起動スクリプトの実行を許可
  shielded_instance_config {
    enable_secure_boot = true
  }
}