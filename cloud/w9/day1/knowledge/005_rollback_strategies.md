# Rollback Strategies

Có 2 cách rollback chính trong GitOps: git revert và kubectl rollout undo

## Git Revert (Recommended)

Đây là recommended approach trong GitOps. Tạo commit mới revert changes.

### How it works

```bash
# Current state: deploy v1.3.0 (broken)
git log
commit abc123 "deploy: update to v1.3.0"
commit def456 "deploy: update to v1.2.0"

# Revert to v1.2.0
git revert abc123

# New commit created
commit xyz789 "Revert deploy: update to v1.3.0"

# Push
git push
```

ArgoCD detect commit mới và sync lại cluster về v1.2.0

### Steps

1. Identify bad commit
```bash
git log --oneline
abc123 deploy: update to v1.3.0  <- bad
def456 deploy: update to v1.2.0  <- last good
```

2. Revert
```bash
git revert abc123
```

Git sẽ mở editor để edit commit message. Save và close.

3. Push
```bash
git push origin main
```

4. ArgoCD auto-sync (nếu enabled) hoặc manual sync
```bash
argocd app sync myapp
```

5. Verify
```bash
kubectl get pods
kubectl logs deployment/myapp
```

### Ưu điểm

- History đầy đủ, clear audit trail
- Có thể revert lại cái revert nếu cần (revert của revert = redeploy)
- Declarative, follow GitOps principles
- Team members thấy rollback trong Git history
- Can be reviewed via PR nếu cần

### Nhược điểm

- Hơi chậm, phải đợi ArgoCD sync (typically 1-3 phút)
- Cần access Git repo (có thể không có nếu oncall)
- Phải biết commit nào cần revert

## kubectl rollout undo

Rollback trực tiếp trên cluster, không qua Git

### How it works

Kubernetes lưu revision history của Deployments:

```bash
# View history
kubectl rollout history deployment/myapp

REVISION  CHANGE-CAUSE
1         Initial deployment
2         Update to v1.2.0
3         Update to v1.3.0
```

Rollback về revision trước:
```bash
kubectl rollout undo deployment/myapp
```

Hoặc specific revision:
```bash
kubectl rollout undo deployment/myapp --to-revision=2
```

### Steps

1. Check current status
```bash
kubectl get deployment myapp
kubectl describe deployment myapp
```

2. View rollout history
```bash
kubectl rollout history deployment/myapp
```

3. Rollback
```bash
# To previous revision
kubectl rollout undo deployment/myapp

# Or specific revision
kubectl rollout undo deployment/myapp --to-revision=2
```

4. Monitor rollout
```bash
kubectl rollout status deployment/myapp
```

5. Verify
```bash
kubectl get pods -w
curl http://myapp.com/health
```

### Ưu điểm

- Rất nhanh, immediate (seconds)
- Không cần access Git
- Useful khi emergency (app completely down)
- Đơn giản, không cần biết Git history

### Nhược điểm

- Tạo drift giữa Git và cluster
- ArgoCD sẽ detect OutOfSync
- Nếu ArgoCD selfHeal enabled, sẽ sync lại về version lỗi
- Không có Git history của rollback
- Other team members không biết có rollback

## Drift Problem với kubectl undo

Scenario:

1. Git có image: myapp:v1.3.0 (broken)
2. kubectl rollout undo về v1.2.0
3. Cluster running v1.2.0, Git có v1.3.0
4. ArgoCD detect drift

Nếu selfHeal enabled:
```yaml
syncPolicy:
  automated:
    selfHeal: true
```

ArgoCD sẽ sync lại về v1.3.0 sau vài phút, broken lại

### Fix drift

Phải update Git sau khi kubectl undo:

```bash
# 1. kubectl undo (immediate fix)
kubectl rollout undo deployment/myapp

# 2. Update Git
cd gitops-repo
# Edit manifest về v1.2.0
git add .
git commit -m "rollback: revert to v1.2.0 after kubectl undo"
git push

# 3. Now Git matches cluster
```

## Best Practices

### Production

Use git revert:
- Proper audit trail
- Follow GitOps principles
- Reviewable changes
- No drift

Process:
```
Alert fires → Oncall reviews → Identify bad deploy → 
git revert → Create PR → Quick review → Merge → 
ArgoCD syncs → Verify fix
```

Nếu urgent, skip PR:
```
git revert → git push → argocd app sync --force
```

### Emergency

Nếu app completely down và every second matters:

```bash
# 1. Immediate fix
kubectl rollout undo deployment/myapp

# 2. Verify app up
curl http://myapp.com/health

# 3. Temporary disable ArgoCD sync
argocd app set myapp --sync-policy none

# 4. Fix Git properly
git revert <bad-commit>
git push

# 5. Re-enable ArgoCD
argocd app set myapp --sync-policy automated

# 6. Sync to confirm
argocd app sync myapp
```

### Development/Staging

kubectl undo acceptable:
- Less critical
- Faster iteration
- Can fix Git later
- Team expects some drift

## Helm Rollback

Nếu dùng Helm:

```bash
# View releases
helm list -n production

# View history
helm history myapp -n production

# Rollback
helm rollback myapp 2 -n production
```

Helm rollback cũng tạo drift với Git, cần fix tương tự

## ArgoCD Rollback UI

ArgoCD có rollback feature trong UI:

1. Go to Application
2. Click "History and Rollback"
3. Select revision
4. Click "Rollback"

Về cơ bản đây là kubectl undo với UI, vẫn tạo drift

## Rollback Checklist

Before rollback:
- [ ] Identify root cause (để không rollback nhầm)
- [ ] Confirm last known good version
- [ ] Check if config changes need revert too
- [ ] Notify team (Slack, PagerDuty)

After rollback:
- [ ] Verify app healthy
- [ ] Check metrics back to normal
- [ ] Update incident ticket
- [ ] Fix Git if used kubectl
- [ ] Post-mortem về nguyên nhân

## Preventing Need for Rollback

Best way là không cần rollback:

1. Progressive delivery (Canary)
   - Deploy to 10% users first
   - Auto-rollback nếu metrics bad
   - Learn in Day 3

2. Feature flags
   - Deploy code nhưng feature off
   - Toggle feature on cho small %
   - Rollback = toggle off, không redeploy

3. Testing
   - Staging environment giống prod
   - Load testing
   - Smoke tests sau deploy

4. Monitoring
   - SLO alerts
   - Catch issues early
   - Rollback trước khi ảnh hưởng nhiều users
