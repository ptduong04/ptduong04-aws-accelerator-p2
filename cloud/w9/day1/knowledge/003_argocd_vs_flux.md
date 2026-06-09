# ArgoCD vs Flux

Cả hai đều là GitOps tool nhưng có khác biệt đáng kể

## ArgoCD

### Features

- Có UI đẹp, dễ debug
- CRD riêng cho Application
- Support nhiều source: Git, Helm, Kustomize
- Có rollback UI
- Phổ biến hơn, community lớn
- SSO integration (OIDC, SAML)

### Installation

Cài đặt khá đơn giản:
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get initial password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Application CRD

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  project: default
  
  source:
    repoURL: https://github.com/user/repo
    path: manifests
    targetRevision: main
  
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  
  syncPolicy:
    automated:
      prune: true      # Xóa resources không còn trong Git
      selfHeal: true   # Tự động fix manual changes
    syncOptions:
      - CreateNamespace=true
```

### UI Benefits

- Visual diff giữa Git và cluster
- Click để sync, rollback
- View logs, events của resources
- Resource tree hierarchy
- Health status của từng resource

### CLI

```bash
# Login
argocd login localhost:8080

# Create app
argocd app create myapp \
  --repo https://github.com/user/repo \
  --path manifests \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default

# Sync
argocd app sync myapp

# Get status
argocd app get myapp

# Rollback
argocd app rollback myapp <revision>
```

## Flux

### Features

- Lightweight hơn, ít resource
- Native GitOps, không có UI (có UI extension nhưng basic)
- Dùng nhiều CRD nhỏ (GitRepository, Kustomization, HelmRelease)
- Integration tốt với Flagger cho progressive delivery
- Bootstrap cluster dễ

### Installation

```bash
# Install CLI
curl -s https://fluxcd.io/install.sh | sudo bash

# Bootstrap
flux bootstrap github \
  --owner=user \
  --repository=fleet-infra \
  --path=clusters/my-cluster \
  --personal
```

Bootstrap sẽ:
- Install Flux vào cluster
- Create repository nếu chưa có
- Setup deploy keys
- Commit Flux manifests vào repo

### CRDs

Flux dùng nhiều CRD nhỏ thay vì 1 big CRD:

GitRepository:
```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: myapp
spec:
  interval: 1m
  url: https://github.com/user/repo
  ref:
    branch: main
```

Kustomization:
```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: myapp
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: myapp
  path: ./manifests
  prune: true
  wait: true
```

HelmRelease:
```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: nginx
spec:
  interval: 5m
  chart:
    spec:
      chart: nginx
      version: '1.x'
      sourceRef:
        kind: HelmRepository
        name: bitnami
```

### Notification

Flux có notification controller tốt:

```yaml
apiVersion: notification.toolkit.fluxcd.io/v1beta1
kind: Alert
metadata:
  name: slack-alert
spec:
  providerRef:
    name: slack
  eventSeverity: info
  eventSources:
    - kind: Kustomization
      name: '*'
```

## So sánh

| Feature | ArgoCD | Flux |
|---------|--------|------|
| UI | Có, đẹp | Không (có extension cơ bản) |
| Resource Usage | Cao hơn | Nhẹ hơn |
| CRDs | 1 Application CRD | Nhiều CRDs nhỏ |
| Community | Lớn hơn | Nhỏ hơn nhưng growing |
| CNCF | Graduated | Graduated |
| Multi-tenancy | Có Projects | Dùng namespaces |
| SSO | Built-in | Không |
| CLI | Mạnh | Mạnh |
| Image automation | Cần Image Updater | Built-in |

## Khi nào dùng gì

Dùng ArgoCD khi:
- Team thích UI để debug
- Cần SSO integration
- Multi-tenancy với Projects
- Muốn community lớn, nhiều docs

Dùng Flux khi:
- Cần lightweight, minimal footprint
- Native Kubernetes approach
- Integration với Flagger
- Bootstrap nhiều clusters
- Image update automation

Theo mentor thì production thường dùng ArgoCD vì UI giúp debug nhanh, còn Flux thì phù hợp khi muốn minimal footprint hoặc manage nhiều clusters

## ArgoCD Image Updater

ArgoCD không có image automation built-in, cần cài ArgoCD Image Updater riêng:

```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml
```

Config trong Application:
```yaml
metadata:
  annotations:
    argocd-image-updater.argoproj.io/image-list: myapp=myregistry/myapp
    argocd-image-updater.argoproj.io/myapp.update-strategy: latest
```

Image Updater sẽ check registry và update image tag tự động

## Hybrid Approach

Một số company dùng cả hai:
- ArgoCD cho application deployment (UI benefits)
- Flux cho infrastructure/platform (bootstrap, image automation)

Hoặc:
- ArgoCD cho production (UI, audit)
- Flux cho dev/staging (lightweight)
