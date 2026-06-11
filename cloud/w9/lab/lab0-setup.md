# Lab 0: Dựng Cụm + App + Git

## Mục Tiêu
- Tạo Kubernetes cluster với minikube
- Tạo GitHub repo
- Viết manifest YAML đơn giản
- Push lên Git (CHƯA apply vào cụm - để ArgoCD làm sau)

## Bước 1: Tạo Minikube Cluster

```bash
# Tạo cluster tên w9
minikube start -p w9 --driver=docker --cpus=4 --memory=4096

# Verify
kubectl cluster-info
kubectl get nodes
```

**Expected Output:**
```
NAME   STATUS   ROLES           AGE   VERSION
w9     Ready    control-plane   1m    v1.28.x
```

## Bước 2: Tạo GitHub Repo

### Option 1: Qua GitHub Web UI
1. Đi đến https://github.com/new
2. Repository name: `gitops`
3. Public
4. **KHÔNG** chọn "Initialize this repository with a README"
5. Click "Create repository"

### Option 2: Qua GitHub CLI
```bash
# Nếu đã cài gh CLI
gh repo create gitops --public --source=. --remote=origin
```

## Bước 3: Clone Repo & Tạo Structure

```bash
# Clone về local
cd d:\Cloud\cloud\w9\lab
git clone https://github.com/<YOUR_USERNAME>/gitops.git
cd gitops

# Tạo thư mục
mkdir k8s
mkdir -p argocd/apps
```

## Bước 4: Viết Manifest

Tạo file `k8s/web.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: demo

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: demo
spec:
  replicas: 2
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

## Bước 5: Push Lên Git

```bash
# Add và commit
git add .
git commit -m "feat: add web deployment manifest"

# Push lên GitHub
git push -u origin main
```

## Bước 6: Verify

### Check Git
Đi đến `https://github.com/<YOUR_USERNAME>/gitops` và xác nhận:
- ✅ Có thư mục `k8s/`
- ✅ Có file `k8s/web.yaml`

### Check Cluster (CHƯA deploy)
```bash
kubectl get ns demo
# Output: Error from server (NotFound): namespaces "demo" not found
```

**Đúng!** Vì chúng ta CHƯA apply manifest vào cụm. ArgoCD sẽ làm việc này ở Lab 2.

## Checkpoint ✅

Hoàn thành khi:
- ✅ Cluster `w9` đang chạy
- ✅ Repo `gitops` có file `k8s/web.yaml`
- ✅ File đã được push lên GitHub
- ✅ Namespace `demo` CHƯA tồn tại trong cluster

## Troubleshooting

### Minikube start failed
```bash
# Xóa cluster cũ và thử lại
minikube delete -p w9
minikube start -p w9 --driver=docker --cpus=4 --memory=4096
```

### Git push bị reject
```bash
# Set remote URL
git remote set-url origin https://github.com/<YOUR_USERNAME>/gitops.git

# Hoặc dùng SSH
git remote set-url origin git@github.com:<YOUR_USERNAME>/gitops.git
```

### Docker driver không hoạt động
```bash
# Check Docker đang chạy
docker ps

# Nếu không, start Docker Desktop
```

## Commands Tóm Tắt

```bash
# 1. Create cluster
minikube start -p w9 --driver=docker --cpus=4 --memory=4096

# 2. Clone repo
git clone https://github.com/<YOUR_USERNAME>/gitops.git
cd gitops

# 3. Create structure
mkdir k8s argocd/apps -p

# 4. Create manifest (copy from above)
# Edit k8s/web.yaml

# 5. Push to Git
git add .
git commit -m "feat: add web deployment manifest"
git push -u origin main

# 6. Verify cluster (should be empty)
kubectl get ns demo  # Should return NotFound
```

## Next Lab

Tiếp theo: **Lab 1 - Cài ArgoCD** 🔧

Chúng ta sẽ cài "người thợ" ArgoCD vào cluster để nó tự động kéo manifest từ Git và deploy.

---

**Lab 0 Complete!** ✨
