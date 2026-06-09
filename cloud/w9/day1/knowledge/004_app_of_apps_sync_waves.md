# App of Apps và Sync Waves

## App of Apps Pattern

Đây là pattern để manage nhiều applications. Thay vì tạo từng Application resource manually, tạo 1 "root app" để manage các apps khác.

### Why App of Apps

Problem:
- Có 10 microservices
- Mỗi service cần 1 Application resource
- Phải kubectl apply 10 Application manifests
- Thêm service mới phải apply manually

Solution:
- Tạo 1 root Application
- Root app sync folder chứa các Application manifests
- Thêm service mới = thêm file trong folder
- Root app tự động deploy app mới

### Structure

```
gitops-repo/
├── root-app.yaml              # Root Application
└── apps/
    ├── frontend-app.yaml      # Application cho frontend
    ├── backend-app.yaml       # Application cho backend
    ├── database-app.yaml      # Application cho database
    └── monitoring-app.yaml    # Application cho monitoring
```

### Root Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-app
  namespace: argocd
spec:
  project: default
  
  source:
    repoURL: https://github.com/user/gitops-repo
    path: apps
    targetRevision: main
  
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Child Applications

apps/frontend-app.yaml:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: frontend
  namespace: argocd
spec:
  project: default
  
  source:
    repoURL: https://github.com/user/frontend
    path: k8s
    targetRevision: main
  
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  
  syncPolicy:
    automated:
      prune: true
```

### Bootstrap Process

```bash
# Apply root app only
kubectl apply -f root-app.yaml

# Root app sẽ tự:
# 1. Sync apps/ folder
# 2. Tạo các Application resources
# 3. Các Application đó sẽ deploy services
```

### Multi-Environment

Structure cho nhiều environments:

```
gitops-repo/
├── root-dev.yaml
├── root-staging.yaml
├── root-prod.yaml
└── apps/
    ├── dev/
    │   ├── frontend-app.yaml
    │   └── backend-app.yaml
    ├── staging/
    │   ├── frontend-app.yaml
    │   └── backend-app.yaml
    └── prod/
        ├── frontend-app.yaml
        └── backend-app.yaml
```

Mỗi environment có root app riêng point tới folder tương ứng

### Benefits

- Bootstrap cluster dễ dàng (1 kubectl apply)
- Add service mới = add file, không cần kubectl
- Consistent structure across environments
- Declarative management của Applications
- Easy to see toàn bộ apps trong cluster

## Sync Waves

Sync waves giải quyết vấn đề dependency giữa các resources. Ví dụ database phải deploy trước application.

### Problem

Khi ArgoCD sync, mặc định tất cả resources deploy cùng lúc:
- Namespace, ConfigMap, Deployment tạo đồng thời
- Application Pod start trước khi ConfigMap ready
- Pod crash vì missing config

### Solution: Sync Waves

Dùng annotation để set order:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"
```

Wave càng nhỏ deploy càng sớm. Mặc định là 0.

ArgoCD sẽ:
1. Deploy tất cả resources của wave -5
2. Đợi chúng healthy
3. Deploy wave -4
4. Đợi healthy
5. Tiếp tục...

### Example

Namespace và Secrets trước:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: myapp
  annotations:
    argocd.argoproj.io/sync-wave: "-2"
---
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
data:
  password: cGFzc3dvcmQ=
```

Deployment sau:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec:
  template:
    spec:
      containers:
      - name: app
        envFrom:
        - secretRef:
            name: db-secret
```

Service và Ingress cuối:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp
  annotations:
    argocd.argoproj.io/sync-wave: "1"
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp
  annotations:
    argocd.argoproj.io/sync-wave: "2"
```

### Typical Wave Structure

```
Wave -5: CRDs
Wave -4: Namespaces
Wave -3: ServiceAccounts, RBAC
Wave -2: ConfigMaps, Secrets
Wave -1: PVCs, Storage
Wave 0:  Deployments, StatefulSets (default)
Wave 1:  Services
Wave 2:  Ingress, Routes
Wave 3:  Jobs (post-deploy tasks)
Wave 4:  Monitoring, Alerts
```

### Sync Phase

Ngoài wave còn có sync phase annotation:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/hook: PreSync
```

Phases:
- PreSync: Trước khi sync (database migration)
- Sync: Normal sync (default)
- PostSync: Sau khi sync (smoke tests)
- SyncFail: Nếu sync fail (rollback, notification)

Example PreSync Job:
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      containers:
      - name: migrate
        image: myapp:latest
        command: ["npm", "run", "migrate"]
      restartPolicy: Never
```

Hook delete policy:
- HookSucceeded: Xóa nếu success
- HookFailed: Xóa nếu fail
- BeforeHookCreation: Xóa hook cũ trước khi tạo mới

### Combining App of Apps with Sync Waves

Root app có thể dùng waves để control order deploy các child apps:

apps/database-app.yaml:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: database
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
```

apps/backend-app.yaml:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: backend
  annotations:
    argocd.argoproj.io/sync-wave: "0"
```

apps/frontend-app.yaml:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: frontend
  annotations:
    argocd.argoproj.io/sync-wave: "1"
```

Database deploy trước, backend giữa, frontend cuối

### Best Practices

1. Không dùng quá nhiều waves
   - Mỗi wave thêm delay
   - Chỉ dùng khi thật sự cần dependencies
   - Typical: 3-5 waves là đủ

2. Group related resources cùng wave
   - ConfigMaps + Secrets cùng wave
   - Deployments + Services cùng wave nếu không dependent

3. Health check phải correct
   - ArgoCD đợi resources healthy mới sang wave tiếp
   - Nếu health check sai, sẽ stuck

4. Test sync order
   - Delete all resources
   - Let ArgoCD re-sync
   - Verify order correct

5. Document wave structure
   - Comment trong manifests
   - README explaining wave strategy
