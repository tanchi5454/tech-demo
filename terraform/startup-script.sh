# !/bin/bash
set -e
set -u

# MongoDB 7.0 (古いバージョン) のインストール
sed -i '/deb https:\/\/deb.debian.org\/debian bullseye-backports/s/^/#/' /etc/apt/sources.list
sed -i '/deb-src https:\/\/deb.debian.org\/debian bullseye-backports/s/^/#/' /etc/apt/sources.list
apt-get update
apt-get install -y gnupg curl
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
   sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg \
   --dearmor
echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] http://repo.mongodb.org/apt/debian bookworm/mongodb-org/7.0 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
apt-get update
sudo apt-get install -y \
   mongodb-org=7.0.12 \
   mongodb-org-database=7.0.12 \
   mongodb-org-server=7.0.12 \
   mongodb-mongosh \
   mongodb-org-shell=7.0.12 \
   mongodb-org-mongos=7.0.12 \
   mongodb-org-tools=7.0.12 \
   mongodb-org-database-tools-extra=7.0.12
echo "mongodb-org hold" | sudo dpkg --set-selections
echo "mongodb-org-database hold" | sudo dpkg --set-selections
echo "mongodb-org-server hold" | sudo dpkg --set-selections
echo "mongodb-mongosh hold" | sudo dpkg --set-selections
echo "mongodb-org-mongos hold" | sudo dpkg --set-selections
echo "mongodb-org-cryptd hold" | sudo dpkg --set-selections
echo "mongodb-org-tools hold" | sudo dpkg --set-selections
echo "mongodb-org-database-tools-extra hold" | sudo dpkg --set-selections

# IPバインディングを 0.0.0.0 に変更
sed -i "s/bindIp: 127.0.0.1/bindIp: 0.0.0.0/" /etc/mongod.conf

# 認証を有効にする
echo -e "\nsecurity:\n  authorization: enabled" >> /etc/mongod.conf

systemctl restart mongod
systemctl enable mongod

# gcloud CLI のインストール（追加）
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
apt-get update && apt-get install -y google-cloud-sdk

# Secret Managerから認証情報を取得
MONGO_USER=$(gcloud secrets versions access latest --secret="mongodb-user" --project="techdemo-01")
MONGO_PASS=$(gcloud secrets versions access latest --secret="mongodb-password" --project="techdemo-01")

# Secret Managerから認証情報を取得
MONGO_USER=$(gcloud secrets versions access latest --secret="mongodb-user" --project="techdemo-01")
MONGO_PASS=$(gcloud secrets versions access latest --secret="mongodb-password" --project="techdemo-01")

# 取得した認証情報でDBユーザーを作成
sleep 10
mongo --eval "db.getSiblingDB('admin').createUser({user: '\$MONGO_USER', pwd: '\$MONGO_PASS', roles: [{role: 'readWriteAnyDatabase', db: 'admin'}]})"

# バックアップスクリプトの作成（認証情報を使用するよう更新）
cat <<EOT > /usr/local/bin/backup-mongo.sh
#!/bin/bash
BACKUP_DIR="/var/backups/mongodb"
TIMESTAMP=\$(date +"%Y%m%d%H%M")
BACKUP_NAME="mongodb-backup-\$TIMESTAMP"
BUCKET_NAME="techdemo-01-db-backups"

mkdir -p \$BACKUP_DIR
mongodump --out \$BACKUP_DIR/\$BACKUP_NAME --authenticationDatabase admin -u "\$MONGO_USER" -p "\$MONGO_PASS"
tar -czvf \$BACKUP_DIR/\$BACKUP_NAME.tar.gz -C \$BACKUP_DIR \$BACKUP_NAME

gsutil cp \$BACKUP_DIR/\$BACKUP_NAME.tar.gz gs://\$BUCKET_NAME/

rm -rf \$BACKUP_DIR/*
EOT

chmod +x /usr/local/bin/backup-mongo.sh

# cronジョブの作成
(crontab -l 2>/dev/null; echo "0 3 * * * /usr/local/bin/backup-mongo.sh") | crontab -
