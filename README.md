# tech-demo
Technical demo environment on GCP with Terraform and GKE

```
.
├── .github/
│   └── workflows/
│       ├── terraform.yml       # インフラ構築用CI/CDパイプライン
│       └── deploy-app.yml      # アプリケーションデプロイ用CI/CDパイプライン
├── app/
│   ├── Dockerfile            # アプリケーションのコンテナイメージ定義
│   ├── main.py               # アプリケーションコード (例: Python Flask)
│   ├── requirements.txt      # Python依存ライブラリ
│   └── wizexercise.txt       # 課題要件のファイル 
├── k8s/
│   ├── deployment.yml        # Kubernetes Deploymentマニフェスト
│   ├── service.yml           # Kubernetes Serviceマニフェスト
│   └── ingress.yml           # Kubernetes Ingressマニフェスト
└── terraform/
    ├── main.tf               # メインのTerraform定義ファイル
    ├── variables.tf          # 変数定義
    └── outputs.tf            # 出力定義
```

