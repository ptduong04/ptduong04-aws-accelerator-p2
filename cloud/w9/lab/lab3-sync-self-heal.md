# Lab 3: Auto-Sync & Self-Heal

## Mục Tiêu
- Test auto-sync: Đổi qua Git → ArgoCD tự apply
- Test self-heal: Đổi kubectl → ArgoCD tự sửa lại

## Test 1: Auto-Sync (Đổi qua Git)

### Bước 1: Tăng Replicas qua Git

Edit file `gitops/k8s/web.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: demo
spec:
  replicas: 5  # ← Đổi từ 2 → 5
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: web
        image: nginx:1.27
        ports:
        - containerPort: 80
```

### Bước 2: Commit & Push

```bash
cd gitops

git add k8s/web.yaml
git commit -m "feat: scale web to 5 replicas"
git push origin main
```

### Bước 3: Watch ArgoCD Sync

```bash
# Watch pods
kubectl -n demo get pods -w
```

**Expected:**
- Sau ~3 phút (ArgoCD poll interval)
- Số pods tăng từ 2 → 5
- ArgoCD UI: Sync status cập nhật

### Verify

```bash
kubectl -n demo get deploy web
# READY should be 5/5

argocd app get web
# Sync Status: Synced to <latest-commit>
```

## Test 2: Self-Heal (Đổi kubectl)

### Bước 1: Scale bằng kubectl

```bash
# Scale trực tiếp (không qua Git)
kubectl -n demo scale deployment web --replicas=8
```

### Bước 2: Check ngay

```bash
kubectl -n demo get deploy web
# READY: 8/8 (temporarily)
```

### Bước 3: Watch Self-Heal

```bash
# Watch pods
kubectl -n demo get pods -w
```

**Expected:**
- Sau vài giây, ArgoCD phát hiện drift
- ArgoCD tự scale về 5 (như Git nói)
- 3 pods bị terminate

### Verify

```bash
kubectl -n demo get deploy web
# READY: 5/5 (back to Git state)

argocd app get web
# Health Status: Healthy
# Sync Status: Synced
```

### Check UI

ArgoCD UI → App "web" → Events tab:
- Sẽ thấy event: "Sync operation to <commit-hash>"
- "Successfully synced application"

## Test 3: Đổi Image qua Git

### Bước 1: Update Image

Edit `gitops/k8s/web.yaml`:

```yaml
spec:
  template:
    spec:
      containers:
      - name: web
        image: nginx:1.26  # ← Downgrade version
        ports:
        - containerPort: 80
```

### Bước 2: Push

```bash
git add k8s/web.yaml
git commit -m "chore: downgrade nginx to 1.26"
git push origin main
```

### Bước 3: Watch Rolling Update

```bash
# Watch pods rolling update
kubectl -n demo get pods -w
```

**Expected:**
- Pods cũ (nginx:1.27) terminate
- Pods mới (nginx:1.26) create
- Rolling update style

### Verify

```bash
kubectl -n demo get pods -o jsonpath='{.items[0].spec.containers[0].image}'
# Output: nginx:1.26
```

## Test 4: Delete Resource (Prune)

### Bước 1: Xóa Service khỏi Git

Edit `gitops/k8s/web.yaml`, xóa section Service:

```yaml
# XÓA phần này:
---
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: demo
spec:
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

### Bước 2: Push

```bash
git add k8s/web.yaml
git commit -m "remove web service"
git push origin main
```

### Bước 3: Watch Prune

```bash
# Check service
kubectl -n demo get svc -w
```

**Expected:**
- Service `web` bị xóa tự động
- Do `prune: true` trong Application

### Verify

```bash
kubectl -n demo get svc web
# Error from server (NotFound)
```

## Checkpoint ✅

Hoàn thành khi hiểu:
- ✅ **Auto-sync**: Đổi Git → ArgoCD tự apply (sau ~3 phút)
- ✅ **Self-heal**: Đổi kubectl → ArgoCD sửa lại (sau vài giây)
- ✅ **Prune**: Xóa khỏi Git → ArgoCD xóa khỏi cluster
- ✅ **Git = Source of Truth**: Cluster luôn = Git

## Sync Policy Explained

```yaml
syncPolicy:
  automated:
    prune: true      # Xóa resources không còn trong Git
    selfHeal: true   # Sửa resources bị thay đổi tay
```

| Setting | Behavior |
|---------|----------|
| `automated: {}` | Auto-sync when Git changes |
| `prune: true` | Delete resources removed from Git |
| `selfHeal: true` | Revert manual changes |
| `syncOptions: [CreateNamespace=true]` | Auto-create namespace |

## GitOps Reconciliation Loop

```
┌─────────────────────────────────────────┐
│                                         │
│   ArgoCD Application Controller         │
│                                         │
│   Every 3 minutes (default):            │
│   1. Poll Git repo                      │
│   2. Compare Git vs Cluster             │
│   3. If different → Sync                │
│                                         │
│   selfHeal enabled:                     │
│   1. Watch cluster changes              │
│   2. If drift detected → Revert         │
│                                         │
└─────────────────────────────────────────┘
```

## Troubleshooting

### Auto-sync không hoạt động

```bash
# Check sync policy
argocd app get web -o yaml | grep -A5 syncPolicy

# Manual sync test
argocd app sync web

# Check repo connection
argocd app get web | grep -i repo
```

### Self-heal không hoạt động ngay

**Normal behavior:**
- Drift detection: vài giây
- Nếu không heal, check `selfHeal: true` trong spec

### Sync quá chậm

```bash
# Giảm polling interval (global setting)
kubectl -n argocd edit cm argocd-cm
# Add: timeout.reconciliation: 60s

# Hoặc force sync
argocd app sync web
```

## Commands Tóm Tắt

```bash
# Test 1: Auto-Sync
# 1. Edit k8s/web.yaml (replicas: 5)
# 2. git commit & push
# 3. Watch: kubectl -n demo get pods -w

# Test 2: Self-Heal
kubectl -n demo scale deployment web --replicas=8
# Watch: kubectl -n demo get pods -w
# Should auto-revert to 5

# Test 3: Change Image
# 1. Edit k8s/web.yaml (image: nginx:1.26)
# 2. git commit & push
# 3. Watch: kubectl -n demo get pods -w

# Test 4: Prune
# 1. Remove Service from k8s/web.yaml
# 2. git commit & push
# 3. Watch: kubectl -n demo get svc -w
```

## Next Lab

Tiếp theo: **Lab 4 - Rollback** ⏮️

Chúng ta sẽ học cách rollback bằng Git khi deploy lỗi.

---

**Lab 3 Complete!** ✨
