# Lab 7: CI/CD Integration với GitHub Actions

## Mục Tiêu
- Tích hợp CI với GitOps
- GitHub Actions build image tự động
- Update manifest → ArgoCD auto-deploy

## Full CI/CD Flow

```
Code Push → GitHub Actions → Build Image → Push Docker Hub → Update Manifest → ArgoCD Sync
```

## Bước 1: Tạo Simple App

Tạo thư mục `app/` với simple Node.js app:

### `app/package.json`

```json
{
  "name": "demo-app",
  "version": "1.0.0",
  "main": "server.js",
  "dependencies": {
    "express": "^4.18.0"
  }
}
```

### `app/server.js`

```javascript
const express = require('express');
const app = express();
const PORT = 3000;

app.get('/', (req, res) => {
  res.json({
    message: 'Hello from GitOps CI/CD!',
    version: process.env.VERSION || '1.0.0',
    timestamp: new Date().toISOString()
  });
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy' });
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
```

### `app/Dockerfile`

```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install --production

COPY server.js ./

EXPOSE 3000

CMD ["node", "server.js"]
```

## Bước 2: Setup Docker Hub

### Tạo Repository

1. Đi đến https://hub.docker.com/
2. Create Repository
3. Name: `demo-app`
4. Visibility: Public

### Tạo Access Token

1. Account Settings → Security → New Access Token
2. Description: "GitHub Actions"
3. Copy token (lưu lại!)

## Bước 3: Configure GitHub Secrets

1. Đi đến repo GitHub: https://github.com/<username>/gitops
2. Settings → Secrets and variables → Actions
3. New repository secret:
   - Name: `DOCKERHUB_USERNAME`
   - Value: `<your-dockerhub-username>`
4. New repository secret:
   - Name: `DOCKERHUB_TOKEN`
   - Value: `<token-from-step-2>`

## Bước 4: Create GitHub Actions Workflow

Tạo `.github/workflows/ci.yaml`:

```yaml
name: CI/CD Pipeline

on:
  push:
    branches:
      - main
    paths:
      - 'app/**'  # Only trigger on app changes

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v3
    
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v2
    
    - name: Login to Docker Hub
      uses: docker/login-action@v2
      with:
        username: ${{ secrets.DOCKERHUB_USERNAME }}
        password: ${{ secrets.DOCKERHUB_TOKEN }}
    
    - name: Generate image tag
      id: tag
      run: echo "TAG=$(date +%Y%m%d-%H%M%S)-${GITHUB_SHA:0:7}" >> $GITHUB_OUTPUT
    
    - name: Build and push Docker image
      uses: docker/build-push-action@v4
      with:
        context: ./app
        push: true
        tags: |
          ${{ secrets.DOCKERHUB_USERNAME }}/demo-app:${{ steps.tag.outputs.TAG }}
          ${{ secrets.DOCKERHUB_USERNAME }}/demo-app:latest
    
    - name: Update Kubernetes manifest
      run: |
        sed -i "s|image:.*demo-app:.*|image: ${{ secrets.DOCKERHUB_USERNAME }}/demo-app:${{ steps.tag.outputs.TAG }}|" k8s/web.yaml
        
    - name: Commit updated manifest
      run: |
        git config --global user.name "GitHub Actions"
        git config --global user.email "actions@github.com"
        git add k8s/web.yaml
        git commit -m "ci: update image to ${{ steps.tag.outputs.TAG }}"
        git push
```

## Bước 5: Update Deployment Manifest

Edit `k8s/web.yaml` để dùng custom app:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: demo
  annotations:
    argocd.argoproj.io/sync-wave: "2"
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
        image: <YOUR_DOCKERHUB_USERNAME>/demo-app:latest  # ← Your image!
        ports:
        - containerPort: 3000
        env:
        - name: VERSION
          value: "1.0.0"
        envFrom:
        - configMapRef:
            name: web-config
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 5

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
    targetPort: 3000
  type: ClusterIP
```

## Bước 6: Commit & Push to Trigger CI

```bash
cd gitops

git add .
git commit -m "feat: add CI/CD pipeline with GitHub Actions"
git push origin main
```

## Bước 7: Watch CI/CD Pipeline

### GitHub Actions

1. Đi đến repo → Actions tab
2. Xem workflow "CI/CD Pipeline" running
3. Click vào run để xem logs

**Stages:**
1. ✅ Checkout code
2. ✅ Build Docker image
3. ✅ Push to Docker Hub
4. ✅ Update manifest with new tag
5. ✅ Commit & push updated manifest

### ArgoCD

```bash
# Watch app sync
argocd app get web --watch

# Watch pods rolling update
kubectl -n demo get pods -w
```

## Bước 8: Verify Deployment

```bash
# Port forward
kubectl port-forward -n demo svc/web 8082:80

# Test API
curl http://localhost:8082
```

**Expected Response:**
```json
{
  "message": "Hello from GitOps CI/CD!",
  "version": "1.0.0",
  "timestamp": "2026-06-11T10:30:00.000Z"
}
```

## Test Full CI/CD Flow

### Step 1: Change Code

Edit `app/server.js`:

```javascript
app.get('/', (req, res) => {
  res.json({
    message: 'Hello from GitOps CI/CD v2!',  // ← Changed!
    version: process.env.VERSION || '2.0.0',  // ← Changed!
    timestamp: new Date().toISOString(),
    environment: 'production'  // ← New field!
  });
});
```

### Step 2: Commit & Push

```bash
git add app/server.js
git commit -m "feat: update API response v2"
git push origin main
```

### Step 3: Watch the Magic ✨

**Timeline:**
```
T+0s:   Push to GitHub
T+10s:  GitHub Actions triggered
T+30s:  Docker image built
T+60s:  Image pushed to Docker Hub
T+90s:  Manifest updated with new tag
T+95s:  Manifest pushed to Git
T+180s: ArgoCD detects change (3 min poll)
T+190s: Pods rolling update
T+220s: New version deployed!
```

### Step 4: Verify Update

```bash
curl http://localhost:8082
```

**Expected:**
```json
{
  "message": "Hello from GitOps CI/CD v2!",
  "version": "2.0.0",
  "timestamp": "2026-06-11T10:35:00.000Z",
  "environment": "production"
}
```

## Full CI/CD Architecture

```
┌─────────────────────────────────────────────────┐
│              Developer Workflow                  │
├─────────────────────────────────────────────────┤
│                                                 │
│  Developer                                      │
│     │                                           │
│     ├─ git commit app/server.js                │
│     └─ git push origin main                    │
│           │                                      │
│           ▼                                      │
│  ┌──────────────────┐                          │
│  │  GitHub Actions  │                          │
│  │  1. Build image  │                          │
│  │  2. Push to Hub  │                          │
│  │  3. Update YAML  │                          │
│  │  4. git push     │                          │
│  └──────────────────┘                          │
│           │                                      │
│           ▼                                      │
│  ┌──────────────────┐    ┌──────────────────┐ │
│  │   Docker Hub     │    │   Git Repo      │ │
│  │   new image      │    │   updated YAML  │ │
│  └──────────────────┘    └──────────────────┘ │
│                                  │              │
│                                  ▼              │
│                         ┌──────────────────┐  │
│                         │     ArgoCD       │  │
│                         │   Auto-sync      │  │
│                         └──────────────────┘  │
│                                  │              │
│                                  ▼              │
│                         ┌──────────────────┐  │
│                         │   Kubernetes     │  │
│                         │   Rolling Update │  │
│                         └──────────────────┘  │
│                                                 │
└─────────────────────────────────────────────────┘
```

## Checkpoint ✅

Hoàn thành khi hiểu:
- ✅ Code push → CI build image tự động
- ✅ Image mới → Update manifest tag
- ✅ Manifest update → ArgoCD sync
- ✅ Full GitOps: Git = single source of truth
- ✅ Zero manual kubectl

## CI/CD vs GitOps

| Traditional CI/CD | GitOps CI/CD |
|-------------------|--------------|
| CI builds + **deploys** directly | CI builds + **updates Git** |
| kubectl/helm from CI | ArgoCD from Git |
| CI needs cluster access | CI only needs Git access |
| Less secure (CI has prod creds) | More secure (pull model) |
| No deployment audit | Full Git history |

## Advanced Patterns

### Multi-Environment

```yaml
# .github/workflows/ci.yaml
- name: Update manifest based on branch
  run: |
    if [ "${{ github.ref }}" == "refs/heads/main" ]; then
      sed -i "s|image:.*|image: $IMAGE:$TAG|" k8s/prod/web.yaml
    else
      sed -i "s|image:.*|image: $IMAGE:$TAG|" k8s/dev/web.yaml
    fi
```

### Kustomize for Multi-Env

```
k8s/
├── base/
│   └── web.yaml
├── overlays/
│   ├── dev/
│   │   └── kustomization.yaml
│   └── prod/
│       └── kustomization.yaml
```

### Image Updater (Alternative)

Thay vì CI update manifest, dùng ArgoCD Image Updater:

```yaml
metadata:
  annotations:
    argocd-image-updater.argoproj.io/image-list: web=docker.io/username/demo-app
    argocd-image-updater.argoproj.io/web.update-strategy: latest
```

## Troubleshooting

### GitHub Actions Failed

```bash
# Check workflow logs
# Go to Actions tab → Click on failed run → View logs

# Common issues:
# - Docker Hub credentials wrong
# - Dockerfile errors
# - sed command syntax (Windows vs Linux)
```

### Manifest Not Updated

```bash
# Check if CI has permissions
# Repository Settings → Actions → General
# Workflow permissions: "Read and write permissions"

# Check git config in workflow
git config --list
```

### ArgoCD Not Syncing

```bash
# Force refresh
argocd app get web --refresh

# Check sync policy
argocd app get web -o yaml | grep -A5 syncPolicy
```

### Image Pull Error

```bash
# Check image exists
docker pull <username>/demo-app:latest

# Check image name in manifest
kubectl -n demo get deploy web -o yaml | grep image:
```

## Commands Tóm Tắt

```bash
# 1. Create app code
mkdir -p app
# Create package.json, server.js, Dockerfile

# 2. Create GitHub Actions workflow
mkdir -p .github/workflows
# Create ci.yaml

# 3. Update manifest
# Edit k8s/web.yaml (use your Docker Hub image)

# 4. Push
git add .
git commit -m "feat: add CI/CD pipeline"
git push origin main

# 5. Watch GitHub Actions
# Go to repo → Actions tab

# 6. Watch ArgoCD
argocd app get web --watch
kubectl -n demo get pods -w

# 7. Test deployment
kubectl port-forward -n demo svc/web 8082:80
curl http://localhost:8082
```

## Congratulations! 🎉

Bạn đã hoàn thành **FULL GitOps CI/CD pipeline**:

✅ **Lab 0**: Setup cluster + Git
✅ **Lab 1**: Install ArgoCD
✅ **Lab 2**: Create Application
✅ **Lab 3**: Auto-sync & Self-heal
✅ **Lab 4**: Git-based Rollback
✅ **Lab 5**: App-of-Apps
✅ **Lab 6**: Sync Waves
✅ **Lab 7**: CI/CD Integration

**You are now a GitOps Engineer!** 🚀

---

**Lab 7 Complete!** ✨
