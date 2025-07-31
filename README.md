# tech-demo
Technical demo environment on GCP

```
.
├── .github/
│   └── workflows/
│       ├── terraform.yml    # GCP環境構築
│       └── deploy-app.yml   # アプリケーションデプロイ
├── app/      # 提供済
│   ├── assets
│   ├── auth
│   ├── controllers
│   ├── database
│   ├── models
│   ├── Dockerfile
│   ├── go.mod
│   ├── go.sum
│   ├── main.go
│   ├── README.md
│   └── wizexercise.txt    # 課題の要件で作成
├── k8s/
│   ├── 01-rbac.yaml          # アプリケーションにクラスタ全体の管理者権限を付与
│   ├── 02-deployment.yaml    # Webアプリケーションをデプロイ
│   ├── 03-service.yml        # Deploymentをクラスタ内で公開する
│   └── 04-ingress.yml        # HTTP(S)ロードバランサ作成
└── terraform/
    ├── main.tf         # メインのGCPリソース (VPC, Firewall, Storage)
    ├── variables.tf    # 変数定義
    ├── vm.tf           # MongoDB VM関連のリソース
    ├── gke.tf          # GKEクラスタ関連のリソース
    └── outputs.tf      # 出力値 (VMのIPアドレスなど)
```

