# Lab 5: App-of-Apps Pattern

## Mục Tiêu
- Tạo "root" Application quản lý tất cả apps
- Thêm app mới chỉ cần thả file YAML + push
- Không cần `kubectl apply` mỗi app

## Problem với Approach Hiện Tại

**Hiện tại (Lab 2):**
```bash
# Mỗi app mới phải apply tay
kubectl apply -f argocd/apps/web.yaml
kubectl apply -f argocd/apps/api.yaml
kubectl apply -f argocd/apps/db.yaml
```

**Problem:**
- ❌ Phải kubectl apply mỗi app
- ❌ Không tự động
- ❌ Quên apply → app không deploy

## Solution: App-of-Apps

**Concept:**
- 1 "root" Application
- Root watches thư mục `argocd/apps/`
- Bất kỳ file `.yaml` nào trong đó → tự động tạo app

## Bước 1: Tạo Root Application

Tạo file `argocd/root.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
  namespace: argocd
spec:
  project: default
  
  source:
    repoURL: https://github.com/<YOUR_USERNAME>/gitops.git
    targetRevision: HEAD
    path: argocd/apps  # ← Watches this directory
  
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd  # ← Apps themselves deployed here
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**Key difference:**
- `path: argocd/apps` → Watches thư mục chứa Application YAMLs
- `destination.namespace: argocd` → Applications (CRDs) deploy vào argocd namespace

## Bước 2: Commit & Push

```bash
cd gitops

git add argocd/root.yaml
git commit -m "feat: add root app-of-apps"
git push origin main
```

## Bước 3: Apply Root (Lần Cuối Apply Tay!)

```bash
kubectl apply -f argocd/root.yaml
```

**Từ giờ:**
- Root tự apply apps trong `argocd/apps/`
- Thêm app mới chỉ cần push file vào `argocd/apps/`

## Bước 4: Verify Root Created Web App

```bash
# Check root app
kubectl -n argocd get app root

# Check root managed apps
argocd app get root

# Check web app (should still be there)
kubectl -n argocd get app web
```

**Expected:**
- App `root`: Synced/Healthy
- App `web`: Synced/Healthy (được root quản lý)

## Bước 5: Test - Add New App

Tạo `argocd/apps/api.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: api
  namespace: argocd
spec:
  project: default
  
  source:
    repoURL: https://github.com/<YOUR_USERNAME>/gitops.git
    targetRevision: HEAD
    path: k8s  # Same manifests (for demo)
  
  destination:
    server: https://kubernetes.default.svc
    namespace: api-namespace
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

## Bước 6: Push (Không Cần kubectl apply!)

```bash
git add argocd/apps/api.yaml
git commit -m "feat: add api application"
git push origin main
```

## Bước 7: Watch Root Auto-Create API App

```bash
# Watch apps
kubectl -n argocd get app -w
```

**Expected:**
- Sau ~3 phút
- App `api` tự động xuất hiện!
- Status: Synced/Healthy

```bash
# Verify
argocd app list

# Output:
# NAME  CLUSTER                         NAMESPACE      PROJECT  STATUS  HEALTH
# root  https://kubernetes.default.svc  argocd         default  Synced  Healthy
# web   https://kubernetes.default.svc  demo           default  Synced  Healthy
# api   https://kubernetes.default.svc  api-namespace  default  Synced  Healthy
```

## Bước 8: Verify API Deployed

```bash
kubectl get ns api-namespace
kubectl -n api-namespace get deploy,pod
```

## App-of-Apps Visualization

```
┌────────────────────────────────────────┐
│         Git Repo (gitops)              │
│                                        │
│  argocd/                               │
│  ├── root.yaml     ← Apply 1 lần      │
│  └── apps/                             │
│      ├── web.yaml  ← Root auto-apply  │
│      ├── api.yaml  ← Root auto-apply  │
│      └── db.yaml   ← Root auto-apply  │
│                                        │
└────────────────────────────────────────┘
                │
                ▼
┌────────────────────────────────────────┐
│         ArgoCD (argocd namespace)      │
│                                        │
│  Application/root  (watches apps/)     │
│    ├── manages → Application/web       │
│    ├── manages → Application/api       │
│    └── manages → Application/db        │
│                                        │
└────────────────────────────────────────┘
                │
                ▼
┌────────────────────────────────────────┐
│         Kubernetes Clusters            │
│                                        │
│  namespace/demo         (web pods)     │
│  namespace/api-namespace (api pods)    │
│  namespace/db           (db pods)      │
│                                        │
└────────────────────────────────────────┘
```

## Benefits

| Before | After (App-of-Apps) |
|--------|---------------------|
| Apply mỗi app tay | Apply root 1 lần duy nhất |
| kubectl apply -f app1.yaml | git push → Done |
| kubectl apply -f app2.yaml | Tự động detect apps mới |
| Manual tracking | Git = source of truth |

## Test: Remove App

```bash
# Remove api app
rm argocd/apps/api.yaml

git add argocd/apps/api.yaml
git commit -m "remove api application"
git push origin main
```

**Expected:**
- App `api` tự động xóa (do `prune: true`)
- Namespace `api-namespace` và resources bị xóa

## Checkpoint ✅

Hoàn thành khi hiểu:
- ✅ Root app quản lý `argocd/apps/` directory
- ✅ Thêm app = Thêm YAML file + push (không cần kubectl)
- ✅ Xóa app = Xóa YAML file + push
- ✅ Bootstrap: Chỉ cần apply `root.yaml` 1 lần

## Advanced: Nested App-of-Apps

```
root (/)
├── platform/ (app-of-apps)
│   ├── prometheus
│   ├── grafana
│   └── loki
└── applications/ (app-of-apps)
    ├── web
    ├── api
    └── worker
```

Mỗi folder có 1 app-of-apps riêng!

## Troubleshooting

### Root không tạo apps

```bash
# Check root status
argocd app get root

# Check repo connection
argocd app get root | grep -i source

# Manual sync
argocd app sync root
```

### App được tạo nhưng OutOfSync

```bash
# Check app định nghĩa
kubectl -n argocd get app <app-name> -o yaml

# Sync app
argocd app sync <app-name>
```

### Xóa app nhưng resources vẫn còn

Kiểm tra `prune: true` trong root app:
```bash
argocd app get root -o yaml | grep -A2 syncPolicy
```

## Commands Tóm Tắt

```bash
# 1. Create root app
# Edit argocd/root.yaml

# 2. Push
git add argocd/root.yaml
git commit -m "feat: add root app-of-apps"
git push origin main

# 3. Apply root (LAST TIME you kubectl apply!)
kubectl apply -f argocd/root.yaml

# 4. Verify
kubectl -n argocd get app
argocd app list

# 5. Add new app (NO kubectl needed!)
# Create argocd/apps/api.yaml
git add argocd/apps/api.yaml
git commit -m "feat: add api application"
git push origin main

# 6. Watch auto-creation
kubectl -n argocd get app -w
```

## Next Lab

Tiếp theo: **Lab 6 - Sync Waves** 🌊

Chúng ta sẽ kiểm soát thứ tự deploy resources.

---

**Lab 5 Complete!** ✨
