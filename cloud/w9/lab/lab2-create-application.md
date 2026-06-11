# Lab 2: Tạo ArgoCD Application

## Mục Tiêu
- Tạo ArgoCD Application CRD
- ArgoCD tự động sync từ Git
- Verify deployment thành công

## Khái Niệm

**Application** là CRD của ArgoCD, định nghĩa:
- Git repo nào
- Path nào trong repo
- Deploy vào namespace nào
- Sync policy như thế nào

## Bước 1: Tạo Application Manifest

Tạo file `argocd/apps/web.yaml` trong repo `gitops`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: web
  namespace: argocd
spec:
  project: default
  
  source:
    repoURL: https://github.com/<YOUR_USERNAME>/gitops.git
    targetRevision: HEAD
    path: k8s
  
  destination:
    server: https://kubernetes.default.svc
    namespace: demo
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

**Giải thích các fields:**

```yaml
metadata:
  name: web                    # Tên app trong ArgoCD
  namespace: argocd            # ArgoCD Application luôn ở ns argocd

spec:
  source:
    repoURL: ...               # Git repo URL
    targetRevision: HEAD       # Branch/tag/commit (HEAD = main branch)
    path: k8s                  # Thư mục chứa manifests

  destination:
    server: ...                # Cluster đích (in-cluster = kubernetes.default.svc)
    namespace: demo            # Deploy vào namespace này

  syncPolicy:
    automated:
      prune: true              # Xóa resources không còn trong Git
      selfHeal: true           # Tự sửa khi bị kubectl thay đổi
    syncOptions:
    - CreateNamespace=true     # Tự tạo namespace nếu chưa có
```

**Thay `<YOUR_USERNAME>`** bằng GitHub username của bạn!

## Bước 2: Commit & Push

```bash
cd gitops

# Add file mới
git add argocd/apps/web.yaml

# Commit
git commit -m "feat: add ArgoCD Application for web"

# Push
git push origin main
```

## Bước 3: Apply Application (Lần Này Apply TAY)

```bash
# Apply Application CRD vào cluster
kubectl apply -f argocd/apps/web.yaml
```

**Lưu ý quan trọng:**
- File này bạn apply TAY lần đầu
- Từ Lab 5, `root` app sẽ tự apply thay bạn

## Bước 4: Verify qua CLI

```bash
# Check Application status
kubectl -n argocd get app web

# hoặc dùng ArgoCD CLI
argocd app get web
```

**Expected Output:**
```
Name:               web
Project:            default
Server:             https://kubernetes.default.svc
Namespace:          demo
URL:                https://localhost:8080/applications/web
Repo:               https://github.com/<username>/gitops.git
Target:             HEAD
Path:               k8s
SyncWindow:         Sync Allowed
Sync Policy:        Automated (Prune)
Sync Status:        Synced to HEAD (xxxxx)
Health Status:      Healthy
```

## Bước 5: Verify Resources Deployed

```bash
# Check namespace (ArgoCD tự tạo)
kubectl get ns demo

# Check deployment
kubectl -n demo get deploy web

# Check pods
kubectl -n demo get pods

# Check service
kubectl -n demo get svc web
```

**Expected Output:**
```
NAME                  READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/web   2/2     2            2           1m

NAME                      READY   STATUS    RESTARTS   AGE
pod/web-xxxxxxxxxx-xxxxx  1/1     Running   0          1m
pod/web-xxxxxxxxxx-xxxxx  1/1     Running   0          1m

NAME          TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/web   ClusterIP   10.96.xxx.xxx   <none>        80/TCP    1m
```

## Bước 6: Verify qua ArgoCD UI

1. Mở https://localhost:8080
2. Click vào application "web"
3. Xem:
   - **Sync Status**: Synced
   - **Health**: Healthy
   - **Topology view**: Deployment → ReplicaSet → Pods

## Test Application

```bash
# Port forward để test
kubectl port-forward -n demo svc/web 8081:80

# Test (terminal mới hoặc browser)
curl http://localhost:8081
# hoặc mở browser: http://localhost:8081
```

**Expected:** Nginx welcome page

## Checkpoint ✅

Hoàn thành khi:
- ✅ Application `web` = Synced/Healthy
- ✅ Namespace `demo` tồn tại
- ✅ Deployment `web` có 2 pods Running
- ✅ ArgoCD UI hiển thị app với topology
- ✅ Curl/browser vào service trả về Nginx page

## Troubleshooting

### App OutOfSync

```bash
# Force sync
argocd app sync web

# Hoặc qua UI: click "Sync" button
```

### App Degraded/Unhealthy

```bash
# Check app details
argocd app get web

# Check pods
kubectl -n demo get pods
kubectl -n demo describe pod <pod-name>

# Check logs
kubectl -n demo logs <pod-name>
```

### "Repository not accessible"

Kiểm tra:
1. URL đúng chưa: `https://github.com/<username>/gitops.git`
2. Repo là public
3. Path `k8s` tồn tại trong repo

### Namespace không tự tạo

Kiểm tra `syncOptions`:
```yaml
syncPolicy:
  syncOptions:
  - CreateNamespace=true
```

Nếu không có, add vào và apply lại.

## GitOps Flow Visualization

```
┌─────────────┐
│  Developer  │
│  git push   │
└──────┬──────┘
       │
       ▼
┌─────────────────┐     ┌───────────────────┐
│   Git Repo      │ ◄───┤  ArgoCD watches   │
│   k8s/web.yaml  │     │  every 3 minutes  │
└─────────────────┘     └───────────────────┘
                                 │
                                 ▼
                        ┌─────────────────┐
                        │  ArgoCD applies │
                        │  to cluster     │
                        └────────┬────────┘
                                 │
                                 ▼
                        ┌─────────────────┐
                        │   Kubernetes    │
                        │   Deployment    │
                        │   2 nginx pods  │
                        └─────────────────┘
```

## Commands Tóm Tắt

```bash
# 1. Create Application manifest
# Edit gitops/argocd/apps/web.yaml

# 2. Push to Git
cd gitops
git add argocd/apps/web.yaml
git commit -m "feat: add ArgoCD Application for web"
git push origin main

# 3. Apply Application
kubectl apply -f argocd/apps/web.yaml

# 4. Verify
kubectl -n argocd get app web
kubectl -n demo get deploy,pod,svc

# 5. Check UI
# https://localhost:8080 → Click "web"

# 6. Test
kubectl port-forward -n demo svc/web 8081:80
curl http://localhost:8081
```

## Next Lab

Tiếp theo: **Lab 3 - Sync & Self-Heal** 🔄

Chúng ta sẽ test auto-sync và self-healing capabilities.

---

**Lab 2 Complete!** ✨
