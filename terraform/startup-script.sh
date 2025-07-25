#!/bin/bash
set -euxo pipefail

# --- パッケージソースの準備 ---
echo "Configuring package sources..."
# 必要なツールを最初にインストール
apt-get update
apt-get install -y gnupg curl

# ★★★ 修正: curlの書き込みエラーを回避するため、一時ファイルにダウンロードする方法に変更 ★★★
# MongoDB 7.0 GPGキーのインポート
echo "Importing MongoDB GPG key..."
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc -o /tmp/mongodb.gpg
cat /tmp/mongodb.gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/mongodb-org-7.0.gpg

# Debian 11 (Bullseye) 用のMongoDBリポジトリを追加
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/debian bullseye/mongodb-org/7.0 main" | \
   sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list

# ★★★ 修正: Google Cloud SDKのキーも同様に修正 ★★★
# Google Cloud SDK GPGキーのインポート
echo "Importing Google Cloud SDK GPG key..."
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg -o /tmp/gcloud.gpg
cat /tmp/gcloud.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg

# Google Cloud SDKリポジトリを追加
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | \
  sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list


# --- パッケージのインストール ---
# すべてのリポジトリを追加した後、一度だけパッケージリストを更新します
echo "Updating package lists..."
apt-get update

echo "Installing MongoDB and Google Cloud SDK..."
# --allow-downgrades は依存関係の問題を解決するために追加
apt-get install -y --allow-downgrades mongodb-org mongodb-mongosh google-cloud-sdk


# --- MongoDBの設定 ---
echo "Configuring MongoDB..."
# IPバインディングを 0.0.0.0 に変更して外部からの接続を許可
sed -i "s/bindIp: 127.0.0.1/bindIp: 0.0.0.0/" /etc/mongod.conf
# 認証を有効にする
echo -e "\nsecurity:\n  authorization: enabled" >> /etc/mongod.conf

# MongoDB サービスを開始・有効化
systemctl restart mongod
systemctl enable mongod

# --- データベースとユーザーのセットアップ ---
echo "Waiting for MongoDB to become available..."
# MongoDBが接続を受け付けるまで待機
for i in {1..30}; do
    if mongosh --eval "db.adminCommand('ping')" --quiet; then
        echo "MongoDB is ready to accept connections."
        break
    fi
    echo "Waiting for MongoDB... ($i/30)"
    sleep 2
done
if ! mongosh --eval "db.adminCommand('ping')" --quiet; then
    echo "::error::MongoDB failed to become available in time."
    journalctl -u mongod --no-pager
    exit 1
fi

# Secret Managerから認証情報を取得
MONGO_USER=$(gcloud secrets versions access latest --secret="mongodb-user" --project="techdemo-01")
MONGO_PASS=$(gcloud secrets versions access latest --secret="mongodb-password" --project="techdemo-01")

# 取得した認証情報でDBユーザーを作成
echo "Creating MongoDB user..."
mongosh --eval "db.getSiblingDB('admin').createUser({user: '\$MONGO_USER', pwd: '\$MONGO_PASS', roles: [{role: 'readWriteAnyDatabase', db: 'admin'}]})"

# todo_db データベースと初期コレクションを作成
echo "Creating default database 'todo_db' and initial collection..."
mongosh "mongodb://\${MONGO_USER}:\${MONGO_PASS}@localhost:27017/todo_db?authSource=admin" --eval "db.createCollection('tasks')"

# --- バックアップの設定 ---
echo "Setting up daily backups..."
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

echo "Startup script finished successfully."