# Lab 6: Sync Waves - Kiểm Soát Thứ Tự Deploy

## Mục Tiêu
- Hiểu vấn đề dependencies giữa resources
- Dùng `sync-wave` annotations để ép thứ tự
- Deploy Namespace → ConfigMap → Deployment đúng thứ tự

## Problem: Deploy Order Matters

**Scenario:**
- Deployment cần đọc ConfigMap
- ConfigMap cần Namespace tồn tại trước

**Without sync waves:**
```
Deployment creates FIRST → ConfigMap not found → CrashLoopBackOff
ConfigMap creates → Too late!
Namespace might be last → Everything fails
```

## Solution: Sync Waves

**Annotations:**
```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"  # Deploy first
```

**Rules:**
- Lower number = Deploy earlier
- Default = wave 0
- Negative numbers OK

## Bước 1: Create ConfigMap

Tạo file `gitops/k8s/configmap.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-config
  namespace: demo
  annotations:
    argocd.argoproj.io/sync-wave: "1"  # Wave 1
data:
  ENV: "production"
  VERSION: "1.0.0"
  LOG_LEVEL: "info"
```

## Bước 2: Update Namespace với Wave

Tạo file `gitops/k8s/namespace.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: demo
  annotations:
    argocd.argoproj.io/sync-wave: "0"  # Wave 0 - First!
```

## Bước 3: Update Deployment để Dùng ConfigMap

Edit `gitops/k8s/web.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: demo
  annotations:
    argocd.argoproj.io/sync-wave: "2"  # Wave 2 - Last!
spec:
  replicas: 3
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
        envFrom:
        - configMapRef:
            name: web-config  # ← Read from ConfigMap
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
```

## Bước 4: Commit & Push

```bash
cd gitops

git add k8s/
git commit -m "feat: add sync waves - namespace -> configmap -> deployment"
git push origin main
```

## Bước 5: Watch Sync Waves in Action

### Terminal 1: Watch Events

```bash
kubectl -n demo get events --watch
```

### Terminal 2: Watch Resources

```bash
watch -n 1 'kubectl -n demo get all,cm'
```

### ArgoCD UI

1. Mở app "web" trong UI
2. Click "Sync"
3. Quan sát tab "Sync"

**Expected Order:**
```
Wave 0: Namespace created
  ↓ (wait for healthy)
Wave 1: ConfigMap created
  ↓ (wait for synced)
Wave 2: Deployment created
  ↓ (pods start with correct env vars)
```

## Bước 6: Verify ConfigMap Loaded

```bash
# Check pod environment
kubectl -n demo exec -it deployment/web -- env | grep -E '(ENV|VERSION|LOG_LEVEL)'
```

**Expected Output:**
```
ENV=production
VERSION=1.0.0
LOG_LEVEL=info
```

## Sync Wave Visualization

```
┌─────────────────────────────────────────────┐
│              ArgoCD Sync Process            │
├─────────────────────────────────────────────┤
│                                             │
│  Wave -1 (if any)                           │
│    └─ Pre-sync hooks                        │
│       (e.g., database migrations)           │
│                                             │
│  ┌─────────────────────┐                   │
│  │ Wave 0              │ ← Apply first      │
│  │ - Namespaces        │                    │
│  │ - CRDs              │                    │
│  └─────────────────────┘                   │
│           │                                  │
│           ▼ Wait for healthy                │
│  ┌─────────────────────┐                   │
│  │ Wave 1              │                    │
│  │ - ConfigMaps        │                    │
│  │ - Secrets           │                    │
│  └─────────────────────┘                   │
│           │                                  │
│           ▼ Wait for synced                 │
│  ┌─────────────────────┐                   │
│  │ Wave 2              │                    │
│  │ - Deployments       │                    │
│  │ - Services          │                    │
│  └─────────────────────┘                   │
│           │                                  │
│           ▼ Wait for healthy                │
│  ┌─────────────────────┐                   │
│  │ Wave 3+ (if any)    │                    │
│  │ - Ingress           │                    │
│  │ - HPA               │                    │
│  └─────────────────────┘                   │
│                                             │
└─────────────────────────────────────────────┘
```

## Common Sync Wave Patterns

### Pattern 1: Infrastructure First

```yaml
# Wave 0: Foundation
- Namespaces
- CRDs (Custom Resource Definitions)
- ServiceAccounts

# Wave 1: Configuration
- ConfigMaps
- Secrets
- PersistentVolumeClaims

# Wave 2: Workloads
- Deployments
- StatefulSets
- DaemonSets
- Services

# Wave 3: Networking & Scaling
- Ingress
- HorizontalPodAutoscaler
```

### Pattern 2: Database Pattern

```yaml
# Wave 0: Database
- StatefulSet (PostgreSQL)
- Service (DB)

# Wave 1: Migrations
- Job (run migrations)

# Wave 2: Application
- Deployment (API server)
```

### Pattern 3: Hooks

```yaml
# Wave -5: Pre-sync
- Job (backup database)

# Wave 0-2: Normal resources

# Wave 100: Post-sync
- Job (warm up cache)
- Job (send notification)
```

## Advanced: Sync Phases

ArgoCD có 3 phases:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/hook: PreSync  # Before sync
    # or: Sync (default)
    # or: PostSync  # After sync
    # or: SyncFail  # If sync fails
    argocd.argoproj.io/sync-wave: "0"
```

**Example: Database Migration Job**

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration
  annotations:
    argocd.argoproj.io/hook: PreSync  # Run before main sync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded  # Delete after success
    argocd.argoproj.io/sync-wave: "-1"  # Before wave 0
spec:
  template:
    spec:
      containers:
      - name: migrate
        image: flyway/flyway
        command: ["flyway", "migrate"]
      restartPolicy: Never
```

## Test Dependency

### Break ConfigMap Dependency

```bash
# Delete ConfigMap manually
kubectl -n demo delete cm web-config

# Watch pods
kubectl -n demo get pods -w
```

**Expected:**
- Pods CrashLoopBackOff (missing ConfigMap)
- ArgoCD detect drift
- Self-heal: Re-create ConfigMap
- Pods recover

## Checkpoint ✅

Hoàn thành khi hiểu:
- ✅ Sync waves kiểm soát thứ tự deploy
- ✅ Lower wave number = Deploy first
- ✅ ArgoCD chờ mỗi wave healthy trước khi tiếp
- ✅ Pattern: Namespace → Config → App
- ✅ Hooks: PreSync, Sync, PostSync, SyncFail

## Best Practices

1. ✅ **Namespace luôn wave 0**
2. ✅ **Config/Secrets: wave 1**
3. ✅ **Workloads: wave 2+**
4. ✅ **Dùng negative waves cho pre-sync jobs**
5. ✅ **Post-sync cleanup: wave 100+**

## Troubleshooting

### Resources không deploy đúng thứ tự

```bash
# Check annotations
kubectl -n demo get deploy web -o yaml | grep sync-wave
kubectl -n demo get cm web-config -o yaml | grep sync-wave

# Check ArgoCD app sync
argocd app get web
```

### Wave bị skip

```bash
# Force sync
argocd app sync web --force

# Check logs
kubectl -n argocd logs deployment/argocd-application-controller
```

### Hook job không chạy

```bash
# Check hook annotation
kubectl get job -A -o yaml | grep -A5 'argocd.argoproj.io/hook'

# Check logs
kubectl logs job/<job-name>
```

## Commands Tóm Tắt

```bash
# 1. Create files with sync-wave annotations
# namespace.yaml (wave 0)
# configmap.yaml (wave 1)
# web.yaml (wave 2)

# 2. Push
git add k8s/
git commit -m "feat: add sync waves"
git push origin main

# 3. Watch sync order
kubectl -n demo get events --watch

# 4. Verify ConfigMap loaded in pods
kubectl -n demo exec -it deployment/web -- env | grep ENV

# 5. Check ArgoCD UI
# Open app → Click Sync → Watch waves
```

## Next Lab

Tiếp theo: **Lab 7 - CI Integration** 🔗

Chúng ta sẽ tích hợp GitHub Actions để build image và update manifest tự động.

---

**Lab 6 Complete!** ✨
