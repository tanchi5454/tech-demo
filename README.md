# tech-demo
Technical demo environment on GCP with Terraform and GKE

```
.
├── .github/
│   └── workflows/
│       ├── terraform.yml    # インフラ構築用CI/CDパイプライン
│       └── deploy-app.yml    # アプリケーションデプロイ用CI/CDパイプライン
├── app/
│   ├── assets    # アプリケーションのアセット
│   ├── auth    # アプリケーションの認証
│   ├── controllers    # アプリケーションのコントローラー
│   ├── database    # アプリケーションのデータベース
│   ├── models    # アプリケーションのモデル
│   ├── Dockerfile    # コンテナイメージ定義
│   ├── go.mod    #
│   ├── go.sum    #
│   ├── main.go    #
│   ├── README.md    #
│   └── wizexercise.txt    #
├── k8s/
│   ├── 00-secret.yaml    # MongoDBの接続情報を保持するSecret
│   ├── 01-rbac.yaml    # アプリケーションにクラスタ全体の管理者権限を付与
│   ├── 02-deployment.yaml    # Webアプリケーションをデプロイ
│   ├── 03-service.yml    # Deploymentをクラスタ内で公開する
│   └── 04-ingress.yml    # HTTP(S)ロードバランサ作成
└── terraform/
    ├── main.tf    # メインのGCPリソース (VPC, Firewall, Storage)
    ├── variables.tf    # 変数定義
    ├── vm.tf    # MongoDB VM関連のリソース
    ├── gke.tf    # GKEクラスタ関連のリソース
    └── outputs.tf    # 出力値 (VMのIPアドレスなど)
```

