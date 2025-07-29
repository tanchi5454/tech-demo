# !/bin/bash
set -euxo pipefail

# 既存のMongoDBリポジトリファイルをクリーンアップ (必要に応じて)
sudo rm -f /etc/apt/trusted.gpg.d/mongodb-org-4.4.gpg # もし以前のバージョンがあれば
sudo rm -f /etc/apt/trusted.gpg.d/mongodb-org-7.0.gpg # 新しいキーを再インポートするため
sudo rm -f /etc/apt/sources.list.d/mongodb-org-4.4.list # もし以前のバージョンがあれば
sudo rm -f /etc/apt/sources.list.d/mongodb-org-7.0.list # 新しいリポジトリを再追加するため

# gnupgとcurlのインストール確認
sudo apt-get install -y gnupg curl

# MongoDB 7.0 GPG Public Keyのインポート
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
   sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg \
   --dearmor

# MongoDB 7.0 リポジトリの追加 (Debian Bullseye用)
echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] http://repo.mongodb.org/apt/debian bullseye/mongodb-org/7.0 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list

# apt パッケージリストの更新
sudo apt-get update

# MongoDB 7.0 のインストール
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
sudo sed -i "s/bindIp: 127.0.0.1/bindIp: 0.0.0.0/" /etc/mongod.conf

# 認証を有効にする
echo -e "\nsecurity:\n  authorization: enabled" >> /etc/mongod.conf

# MongoDB サービスを開始・有効化
sudo systemctl enable mongod
sudo systemctl start mongod

# MongoDBサービスがアクティブになるまで待機するロジックを追加
echo "Waiting for MongoDB to start..."
for i in {1..30}; do
    if mongosh --eval "db.adminCommand('ping')" --quiet; then
        echo "MongoDB is ready to accept connections."
        break
    fi
    echo "Waiting for mongod... ($i/30)"
    sleep 2
done

if ! systemctl is-active --quiet mongod; then
    echo "::error::MongoDB failed to start in time."
    # 失敗した場合にデバッグ用のログを出力
    journalctl -u mongod --no-pager
    exit 1
fi
# サービスがアクティブになった後、ポートがリッスン状態になるまで少し待つ
sleep 5

# Secret Managerから認証情報を取得
MONGO_USER=$(echo -n "$(gcloud secrets versions access latest --secret='mongodb-user')")
MONGO_USER=$(echo -n "$(gcloud secrets versions access latest --secret='mongodb-password')")
# JWT_KEY=$(echo -n "$(gcloud secrets versions access latest --secret='secret-key')")

# 取得した認証情報でDBユーザーを作成
sleep 10
mongosh --eval "db.getSiblingDB('admin').createUser({user: \"${MONGO_USER}\", pwd: \"${MONGO_PASS}\", roles: [{role: 'readWriteAnyDatabase', db: 'admin'}]})"

# todo_db データベースと初期コレクションを作成
echo "Creating default database 'todo_db' and initial collection..."
# 作成したユーザーで認証し、todo_dbデータベース内にtasksコレクションを作成
mongosh "mongodb://${MONGO_USER}:${MONGO_PASS}@localhost:27017/todo_db?authSource=admin" --eval "db.createCollection('tasks')"

# --- バックアップの設定 ---
echo "Setting up daily backups..."
# touchコマンドで空のファイルを作成
sudo touch /usr/local/bin/backup-mongo.sh
# catとteeを使ってスクリプトファイルに内容を書き込む
cat <<EOT | sudo tee /usr/local/bin/backup-mongo.sh
#!/bin/bash
BACKUP_DIR="/var/backups/mongodb"
TIMESTAMP=\$(date +"%Y%m%d%H%M")
BACKUP_NAME="mongodb-backup-\$TIMESTAMP"
BUCKET_NAME="techdemo-01-db-backups"

mkdir -p \$BACKUP_DIR
mongodump --out \$BACKUP_DIR/\$BACKUP_NAME --authenticationDatabase admin -u "${MONGO_USER}" -p "${MONGO_PASS}"
tar -czvf \$BACKUP_DIR/\$BACKUP_NAME.tar.gz -C \$BACKUP_DIR \$BACKUP_NAME

gsutil cp \$BACKUP_DIR/\$BACKUP_NAME.tar.gz gs://\$BUCKET_NAME/

rm -rf \$BACKUP_DIR/*
EOT

sudo chmod +x /usr/local/bin/backup-mongo.sh

# cronジョブの作成
(crontab -l 2>/dev/null; echo "0 3 * * * /usr/local/bin/backup-mongo.sh") | crontab -
