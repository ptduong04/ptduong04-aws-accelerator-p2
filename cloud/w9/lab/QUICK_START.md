# GitOps Lab - Quick Start Guide

## 🚀 Làm Tất Cả Labs Trong 2 Giờ

### Checklist

- [ ] **Lab 0** (15 phút): Setup cluster + Git repo
- [ ] **Lab 1** (10 phút): Install ArgoCD
- [ ] **Lab 2** (15 phút): Create first Application
- [ ] **Lab 3** (10 phút): Test auto-sync & self-heal
- [ ] **Lab 4** (10 phút): Test rollback với Git
- [ ] **Lab 5** (15 phút): Implement app-of-apps
- [ ] **Lab 6** (15 phút): Add sync waves
- [ ] **Lab 7** (20 phút): Setup CI/CD pipeline

**Total: ~110 phút (< 2 giờ)**

## Prerequisites

```bash
# Check installations
docker --version          # Docker Desktop
kubectl version --client  # kubectl
minikube version          # minikube
git --version             # git

# If missing any, install them first!
```

## One-Time Setup (Chỉ Làm 1 Lần)

### 1. Create GitHub Repo

```bash
# On GitHub: Create new repo "gitops" (public, no README)
# Clone it
git clone https://github.com/<YOUR_USERNAME>/gitops.git
cd gitops
```

### 2. Create Directory Structure

```bash
mkdir -p k8s argocd/apps app .github/workflows
```

## Lab Execution Flow

### Lab 0: Setup (15 min)

```bash
# Start cluster
minikube start -p w9 --driver=docker --cpus=4 --memory=4096

# Verify
kubectl get nodes

# Create k8s/web.yaml (copy from lab0-setup.md)
# Commit & push
git add k8s/web.yaml
git commit -m "feat: add web deployment"
git push origin main
```

**✅ Checkpoint:** Repo có file, cluster running, CHƯA deploy

---

### Lab 1: Install ArgoCD (10 min)

```bash
# Install
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ready (2-3 min)
kubectl get pods -n argocd -w

# Expose UI (keep this running in separate terminal)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Login: https://localhost:8080
# Username: admin
# Password: <from above>
```

**✅ Checkpoint:** ArgoCD UI accessible, logged in

---

### Lab 2: Create Application (15 min)

```bash
# Create argocd/apps/web.yaml (copy from lab2-create-application.md)
# REMEMBER: Replace <YOUR_USERNAME> with your GitHub username!

git add argocd/apps/web.yaml
git commit -m "feat: add ArgoCD Application"
git push origin main

# Apply Application (first time - manual)
kubectl apply -f argocd/apps/web.yaml

# Verify
kubectl -n argocd get app web
kubectl -n demo get deploy,pod,svc
```

**✅ Checkpoint:** App "web" = Synced/Healthy, 2 pods running

---

### Lab 3: Test Sync & Heal (10 min)

```bash
# Test 1: Auto-sync (change replicas in Git)
# Edit k8s/web.yaml: replicas: 5
git add k8s/web.yaml
git commit -m "feat: scale to 5 replicas"
git push origin main

# Watch (wait ~3 min)
kubectl -n demo get pods -w

# Test 2: Self-heal (change kubectl)
kubectl -n demo scale deployment web --replicas=8
# Watch it revert to 5
kubectl -n demo get pods -w
```

**✅ Checkpoint:** Replicas = 5, self-heal works

---

### Lab 4: Rollback (10 min)

```bash
# Deploy bad version
# Edit k8s/web.yaml: image: nginx:broken-tag
git add k8s/web.yaml
git commit -m "deploy: bad version"
git push origin main

# Wait ~3 min, verify pods failed
kubectl -n demo get pods

# Rollback
git revert HEAD --no-edit
git push origin main

# Wait ~3 min, verify recovered
kubectl -n demo get pods
```

**✅ Checkpoint:** Pods running again with good image

---

### Lab 5: App-of-Apps (15 min)

```bash
# Create argocd/root.yaml (copy from lab5-app-of-apps.md)
git add argocd/root.yaml
git commit -m "feat: add root app-of-apps"
git push origin main

# Apply root (LAST TIME you kubectl apply!)
kubectl apply -f argocd/root.yaml

# Verify
kubectl -n argocd get app

# Test: Add new app
# Create argocd/apps/api.yaml (copy from lab5)
git add argocd/apps/api.yaml
git commit -m "feat: add api app"
git push origin main

# Watch auto-creation (~3 min)
kubectl -n argocd get app -w
```

**✅ Checkpoint:** Root manages apps, api auto-created

---

### Lab 6: Sync Waves (15 min)

```bash
# Create k8s/namespace.yaml (wave 0)
# Create k8s/configmap.yaml (wave 1)
# Update k8s/web.yaml (wave 2, with envFrom)

git add k8s/
git commit -m "feat: add sync waves"
git push origin main

# Watch sync order
kubectl -n demo get events --watch

# Verify ConfigMap loaded
kubectl -n demo exec -it deployment/web -- env | grep ENV
```

**✅ Checkpoint:** Resources deploy in order, env vars loaded

---

### Lab 7: CI/CD (20 min)

```bash
# 1. Create app code
# Copy package.json, server.js, Dockerfile from lab7

# 2. Create .github/workflows/ci.yaml
# Copy from lab7

# 3. Setup Docker Hub
# - Create repo "demo-app"
# - Create access token
# - Add GitHub secrets: DOCKERHUB_USERNAME, DOCKERHUB_TOKEN

# 4. Update k8s/web.yaml to use your image
# image: <username>/demo-app:latest

# 5. Push
git add .
git commit -m "feat: add CI/CD pipeline"
git push origin main

# 6. Watch GitHub Actions
# Go to repo → Actions tab

# 7. Verify deployment
kubectl port-forward -n demo svc/web 8082:80
curl http://localhost:8082
```

**✅ Checkpoint:** CI builds image, updates manifest, ArgoCD deploys

---

## Troubleshooting

### Minikube Won't Start

```bash
minikube delete -p w9
minikube start -p w9 --driver=docker --cpus=4 --memory=4096
```

### ArgoCD Pods Not Ready

```bash
# Wait longer (can take 3-5 min first time)
kubectl get pods -n argocd -w

# Check logs
kubectl -n argocd logs -l app.kubernetes.io/name=argocd-server
```

### Application OutOfSync

```bash
# Force sync
argocd app sync <app-name>

# Or in UI: Click Sync button
```

### Can't Access UI

```bash
# Check port-forward still running
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Try different port
kubectl port-forward svc/argocd-server -n argocd 8081:443
```

## Quick Commands Reference

```bash
# ArgoCD
argocd app list                    # List apps
argocd app get <name>              # Get app details
argocd app sync <name>             # Force sync
argocd app logs <name>             # View logs

# Kubectl
kubectl -n argocd get app          # List applications
kubectl -n <ns> get deploy,pod,svc # List resources
kubectl -n <ns> logs <pod>         # View logs
kubectl port-forward -n <ns> svc/<name> <local>:<remote>

# Git
git log --oneline                  # View history
git revert HEAD --no-edit          # Rollback
git push origin main               # Push changes
```

## Next Steps After Completing Labs

1. ✅ **Production Setup:**
   - Use Helm for complex apps
   - Implement Kustomize for multi-env
   - Set up proper RBAC

2. ✅ **Monitoring:**
   - Install Prometheus + Grafana
   - ArgoCD metrics
   - Application metrics

3. ✅ **Security:**
   - Use Sealed Secrets for secrets
   - Implement OPA policies
   - Set up SSO for ArgoCD

4. ✅ **Advanced:**
   - Progressive Delivery with Argo Rollouts
   - Blue/Green deployments
   - Canary releases

## Resources

- [ArgoCD Docs](https://argo-cd.readthedocs.io/)
- [OpenGitOps](https://opengitops.dev/)
- [GitOps Working Group](https://github.com/gitops-working-group/gitops-working-group)

---

**Happy GitOps-ing!** 🚀✨
