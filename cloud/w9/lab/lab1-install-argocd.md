# Lab 1: Cài Đặt ArgoCD

## Mục Tiêu
- Cài ArgoCD vào Kubernetes cluster
- Expose ArgoCD UI
- Login vào ArgoCD

## Bước 1: Cài ArgoCD

```bash
# Tạo namespace argocd
kubectl create namespace argocd

# Cài ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

## Bước 2: Đợi Pods Ready

```bash
# Watch pods status
kubectl get pods -n argocd -w

# Hoặc check ngắn gọn
kubectl get pods -n argocd
```

**Expected Output** (sau 2-3 phút):
```
NAME                                  READY   STATUS    RESTARTS   AGE
argocd-application-controller-0       1/1     Running   0          2m
argocd-dex-server-xxx                 1/1     Running   0          2m
argocd-redis-xxx                      1/1     Running   0          2m
argocd-repo-server-xxx                1/1     Running   0          2m
argocd-server-xxx                     1/1     Running   0          2m
```

## Bước 3: Expose ArgoCD Server

### Option 1: Port Forward (Khuyến nghị cho local)

```bash
# Forward port 8080 -> argocd-server:443
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Mở browser: `https://localhost:8080`

**Lưu ý:** Có thể có warning "Your connection is not private" - click "Advanced" → "Proceed to localhost"

### Option 2: NodePort (Alternative)

```bash
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'

# Get URL
minikube service argocd-server -n argocd --url -p w9
```

## Bước 4: Get Admin Password

```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

**Lưu password này lại!**

### Windows (nếu base64 -d không hoạt động):

```powershell
# PowerShell
$password = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($password))
```

## Bước 5: Login vào ArgoCD UI

1. Mở browser: `https://localhost:8080`
2. Username: `admin`
3. Password: (password từ bước 4)
4. Click "Sign In"

**Expected:** Vào được ArgoCD dashboard (trống, chưa có apps)

## Bước 6: Cài ArgoCD CLI (Optional nhưng nên cài)

### Windows

```powershell
# Download
Invoke-WebRequest -Uri https://github.com/argoproj/argo-cd/releases/latest/download/argocd-windows-amd64.exe -OutFile argocd.exe

# Move to PATH
Move-Item .\argocd.exe C:\Windows\System32\argocd.exe
```

### Verify CLI

```bash
argocd version
```

### Login via CLI

```bash
# Port forward đang chạy ở terminal khác

# Login
argocd login localhost:8080 --insecure --username admin --password <YOUR_PASSWORD>

# Verify
argocd app list
```

## Checkpoint ✅

Hoàn thành khi:
- ✅ Tất cả ArgoCD pods = Running
- ✅ Truy cập được ArgoCD UI (localhost:8080)
- ✅ Login thành công với user `admin`
- ✅ Dashboard hiện "No applications" (chưa có app nào)

## Troubleshooting

### Pods không start

```bash
# Check pod logs
kubectl logs -n argocd <pod-name>

# Check events
kubectl get events -n argocd --sort-by='.lastTimestamp'

# Restart nếu cần
kubectl delete pod <pod-name> -n argocd
```

### Port forward bị disconnect

Đây là normal, chỉ cần chạy lại:
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### Cannot get password

```bash
# Check secret exists
kubectl get secret -n argocd argocd-initial-admin-secret

# Manual extract
kubectl get secret argocd-initial-admin-secret -n argocd -o yaml
```

Sau đó decode base64 value manually tại https://www.base64decode.org/

### Browser says "unsafe"

Đây là expected vì self-signed certificate. Click:
- Chrome: "Advanced" → "Proceed to localhost (unsafe)"
- Firefox: "Advanced" → "Accept the Risk and Continue"

## Architecture Hiểu Thêm

ArgoCD components đã cài:

```
┌─────────────────────────────────────────┐
│         argocd namespace                │
│                                         │
│  ┌──────────────┐  ┌─────────────────┐ │
│  │ argocd-server│  │  repo-server    │ │
│  │  (UI + API)  │  │ (Git clone)     │ │
│  └──────────────┘  └─────────────────┘ │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │ application-controller           │  │
│  │ (Reconcile loop - main brain)    │  │
│  └──────────────────────────────────┘  │
│                                         │
│  ┌──────────┐  ┌──────────────────────┐│
│  │  Redis   │  │  Dex (SSO)           ││
│  └──────────┘  └──────────────────────┘│
└─────────────────────────────────────────┘
```

**Key components:**
- **argocd-server**: UI + API
- **application-controller**: Main reconciliation loop
- **repo-server**: Clones Git repos
- **redis**: Cache
- **dex**: Authentication (SSO)

## Commands Tóm Tắt

```bash
# 1. Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 2. Wait for ready
kubectl get pods -n argocd -w

# 3. Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# 4. Get password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# 5. Login at https://localhost:8080
# Username: admin
# Password: <from step 4>
```

## Next Lab

Tiếp theo: **Lab 2 - Tạo Application** 🚀

Chúng ta sẽ tạo ArgoCD Application để sync manifest từ Git vào cluster.

---

**Lab 1 Complete!** ✨
