# Lab 4: Rollback Bằng Git

## Mục Tiêu
- Deploy version có lỗi
- Rollback bằng `git revert`
- Verify rollback thành công trong < 5 phút

## Scenario

Deploy image sai → service down → rollback ngay bằng Git

## Bước 1: Deploy "Bad" Version

Edit `gitops/k8s/web.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: demo
spec:
  replicas: 5
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
        image: nginx:broken-tag  # ← Image không tồn tại!
        ports:
        - containerPort: 80
```

## Bước 2: Commit & Push

```bash
cd gitops

git add k8s/web.yaml
git commit -m "deploy: use nginx:broken-tag (BAD)"
git push origin main
```

## Bước 3: Verify "Disaster"

```bash
# Watch pods
kubectl -n demo get pods -w
```

**Expected:**
- Pods: ImagePullBackOff hoặc ErrImagePull
- Status: NOT Running

```bash
kubectl -n demo get pods
# NAME                  READY   STATUS             RESTARTS   AGE
# web-xxx-xxx           0/1     ImagePullBackOff   0          1m
```

### Check ArgoCD UI

- App status: **Degraded** (red)
- Health: Unhealthy

## Bước 4: Rollback Bằng Git Revert

```bash
# Revert commit cuối (the bad one)
git revert HEAD --no-edit

# Push rollback
git push origin main
```

**`git revert` giải thích:**
- Tạo commit MỚI undoing changes của commit trước
- Không xóa history (khác với `git reset`)
- Safe cho production (có audit trail)

## Bước 5: Watch Recovery

```bash
# Watch pods recover
kubectl -n demo get pods -w
```

**Expected:**
- ArgoCD detect new commit (reverted)
- Pods với nginx:1.26 (good version) deploy lại
- Status: Running

Thời gian: ~3 phút (ArgoCD polling + pod startup)

## Bước 6: Verify Recovery

```bash
# Check deployment
kubectl -n demo get deploy web
# READY: 5/5

# Check image
kubectl -n demo get pods -o jsonpath='{.items[0].spec.containers[0].image}'
# Output: nginx:1.26 (good version)

# Check ArgoCD
argocd app get web
# Health Status: Healthy
# Sync Status: Synced
```

## Git History Visualization

```bash
git log --oneline
```

**Output:**
```
abc123 Revert "deploy: use nginx:broken-tag (BAD)"  ← Rollback commit
def456 deploy: use nginx:broken-tag (BAD)           ← Bad commit
789abc chore: downgrade nginx to 1.26               ← Good state
```

**Ưu điểm:**
- ✅ Full history preserved
- ✅ Audit trail: ai rollback, lúc nào
- ✅ Có thể revert lại revert nếu cần

## Alternative: Rollback Đến Commit Cụ Thể

Nếu muốn rollback về commit cũ hơn:

```bash
# Show history
git log --oneline

# Revert to specific commit (3 commits ago)
git revert HEAD~2 --no-edit
git push origin main
```

## Test Rollback Nhanh Hơn

Nếu muốn ArgoCD sync ngay không đợi 3 phút:

```bash
# Force sync
argocd app sync web --force
```

Hoặc qua UI: Click "Refresh" → "Sync"

## Checkpoint ✅

Hoàn thành khi hiểu:
- ✅ Deploy lỗi → Pods failed
- ✅ `git revert` → Tạo commit mới undo thay đổi
- ✅ ArgoCD auto-sync → Pods recover
- ✅ Git history preserved (có audit trail)
- ✅ Rollback < 5 phút (nhanh hơn rebuild + redeploy)

## GitOps Rollback vs Traditional

### Traditional (Without GitOps):

```
1. Phát hiện lỗi
2. Tìm version trước (tag? commit?)
3. Build lại image (nếu không còn)
4. kubectl set image... (manual command)
5. Không có record ai rollback
```

### GitOps Way:

```
1. Phát hiện lỗi
2. git revert HEAD && git push
3. ArgoCD tự apply
4. Full audit trail in Git
```

**Advantage:**
- ⚡ Faster: Không cần rebuild
- 📝 Auditable: Git commit message
- 🔒 Safer: Git review process
- 🔄 Reproducible: Có thể revert về bất kỳ commit nào

## Rollback Strategies So Sánh

| Strategy | Command | Use Case | Audit Trail |
|----------|---------|----------|-------------|
| **git revert** | `git revert HEAD` | Production (recommended) | ✅ Full |
| **git reset** | `git reset --hard HEAD~1` | Local only | ❌ Removes history |
| **kubectl rollout undo** | `kubectl rollout undo` | Emergency only | ⚠️ Limited (10 revisions) |
| **Manual edit** | `kubectl edit deploy` | ❌ Never | ❌ None |

**Best Practice:** Always use `git revert` for production.

## Troubleshooting

### Revert conflict

```bash
# If revert has conflicts
git revert HEAD
# Fix conflicts manually
git add .
git commit
git push origin main
```

### ArgoCD không detect revert

```bash
# Force refresh
argocd app get web --refresh

# Manual sync
argocd app sync web
```

### Pods vẫn failed sau revert

```bash
# Check ArgoCD synced to correct commit
argocd app get web | grep "Sync Status"

# Check actual image
kubectl -n demo describe pod <pod-name> | grep Image:
```

## Commands Tóm Tắt

```bash
# 1. Deploy bad version
# Edit k8s/web.yaml (image: nginx:broken-tag)
git add k8s/web.yaml
git commit -m "deploy: use nginx:broken-tag (BAD)"
git push origin main

# 2. Verify disaster
kubectl -n demo get pods
# Status: ImagePullBackOff

# 3. Rollback
git revert HEAD --no-edit
git push origin main

# 4. Watch recovery
kubectl -n demo get pods -w

# 5. Verify
argocd app get web
kubectl -n demo get deploy web
```

## Next Lab

Tiếp theo: **Lab 5 - App-of-Apps** 📦

Chúng ta sẽ tạo "root" app quản lý tất cả apps qua 1 thư mục.

---

**Lab 4 Complete!** ✨
