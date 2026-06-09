# Day 1 - GitOps và CI/CD

Ngày hôm nay học về GitOps và CI/CD, khá nhiều concept mới nhưng cũng thú vị

## GitOps là gì

GitOps về cơ bản là dùng Git làm source of truth cho cả infrastructure lẫn application. Thay vì ssh vào server rồi kubectl apply tay, giờ mọi thứ đều qua Git.

Workflow cơ bản:
- Code thay đổi push lên Git
- CI/CD tự động chạy
- Cluster tự sync theo Git
- Nếu ai đó kubectl edit trực tiếp thì sẽ bị revert lại theo Git

Lợi ích chính:
- Audit trail đầy đủ, biết ai thay đổi gì lúc nào
- Rollback dễ, chỉ cần git revert
- Disaster recovery đơn giản, clone repo là có lại hết
- Review changes qua pull request trước khi apply

## GitHub Actions

Đây là CI/CD tool của GitHub, config bằng YAML file trong .github/workflows/

### Plan on PR

Khi tạo pull request, workflow sẽ chạy terraform plan hoặc kubectl diff để show changes. Điều này giúp reviewer biết sẽ thay đổi gì trước khi merge.

```yaml
name: Plan

on:
  pull_request:
    branches:
      - main

jobs:
  plan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Show diff
        run: kubectl diff -f manifests/
```

Cái này rất hữu ích vì reviewer có thể thấy trước impact của changes

### Apply on Merge

Khi PR được merge vào main, workflow khác sẽ tự động apply changes lên cluster

```yaml
name: Deploy

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Deploy
        run: kubectl apply -f manifests/
```

Pattern này đảm bảo chỉ có code đã review mới được deploy

## ArgoCD vs Flux

Cả hai đều là GitOps tool nhưng có khác biệt

### ArgoCD

- Có UI đẹp, dễ debug
- CRD riêng cho Application
- Support nhiều source: Git, Helm, Kustomize
- Có rollback UI
- Phổ biến hơn, community lớn

Cài đặt khá đơn giản:
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Tạo Application:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
spec:
  source:
    repoURL: https://github.com/user/repo
    path: manifests
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Flux

- Lightweight hơn, ít resource
- Native GitOps, không có UI
- Dùng nhiều CRD nhỏ (GitRepository, Kustomization, HelmRelease)
- Integration tốt với Flagger cho progressive delivery

Theo mentor thì production thường dùng ArgoCD vì UI giúp debug nhanh, còn Flux thì phù hợp khi muốn minimal footprint

## App of Apps Pattern

Đây là pattern để manage nhiều applications. Thay vì tạo từng Application resource manually, tạo 1 "root app" để manage các apps khác.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-app
spec:
  source:
    repoURL: https://github.com/user/repo
    path: apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated: {}
```

Trong folder apps/ sẽ có các Application manifests cho từng service. Khi thêm service mới chỉ cần thêm file YAML vào apps/, root app sẽ tự deploy.

Lợi ích:
- Bootstrap cluster dễ dàng
- Manage nhiều environments (dev, staging, prod)
- Consistent structure

## Sync Waves

Sync waves giải quyết vấn đề dependency giữa các resources. Ví dụ database phải deploy trước application.

Dùng annotation để set order:
```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"
```

Wave càng nhỏ deploy càng sớm. Mặc định là 0.

Ví dụ thực tế:
- Wave -1: Namespace, ConfigMap, Secret
- Wave 0: Deployment, Service (default)
- Wave 1: Ingress
- Wave 2: Monitoring, alerts

ArgoCD sẽ đợi wave trước complete rồi mới deploy wave sau

## Rollback Strategies

Có 2 cách rollback chính

### Git Revert

Recommended approach trong GitOps. Tạo commit mới revert changes.

```bash
git revert HEAD
git push
```

ArgoCD detect commit mới và sync lại cluster về state cũ.

Ưu điểm:
- History đầy đủ
- Có thể revert lại cái revert nếu cần
- Declarative, follow GitOps principles

Nhược điểm:
- Hơi chậm, phải đợi ArgoCD sync
- Cần access Git repo

### kubectl rollout undo

Rollback trực tiếp trên cluster

```bash
kubectl rollout undo deployment/myapp
```

Ưu điểm:
- Nhanh, immediate
- Không cần access Git

Nhược điểm:
- Tạo drift giữa Git và cluster
- ArgoCD có thể sync lại về version lỗi nếu selfHeal enabled
- Không có Git history

Best practice:
- Production: dùng git revert
- Emergency (app down, critical): kubectl rollout undo rồi fix Git sau
- Development: tùy, kubectl undo acceptable

## CI/CD Pipeline Design

Học được pattern tổng quát cho production:

```
Developer push code
  |
  v
GitHub Actions CI
  |
  +-- Lint code
  +-- Run tests
  +-- Build Docker image
  +-- Security scan (Trivy)
  +-- Push to registry
  |
  v
Update image tag trong GitOps repo
  |
  v
ArgoCD detect changes
  |
  v
Deploy to cluster
  |
  v
Health checks pass
  |
  v
Notify Slack/Teams
```

Key points:
- CI build artifacts (images)
- CD deploy artifacts (GitOps pull model)
- Separation of concerns rõ ràng
- Git là single source of truth

## Security Considerations

Một số điểm security cần lưu ý:

Secrets management:
- Không commit secrets vào Git
- Dùng Sealed Secrets hoặc External Secrets Operator
- ArgoCD có thể integrate với Vault

RBAC:
- Restrict ai được push vào main branch
- Production changes cần approval
- ArgoCD có RBAC riêng cho UI access

Image signing:
- Sign images với cosign
- Admission controller verify signatures
- Prevent unauthorized images

## Challenges gặp phải

Hôm nay setup ArgoCD gặp mấy vấn đề:

1. Application stuck ở Progressing
   - Check logs thì thiếu RBAC permissions
   - Fix: tạo ServiceAccount với đủ permissions

2. Sync không tự động dù đã set automated
   - Do có resource OutOfSync manually edited
   - Fix: kubectl delete resource đó, để ArgoCD recreate

3. Image pull error
   - Thiếu imagePullSecrets
   - Fix: tạo secret từ registry credentials

