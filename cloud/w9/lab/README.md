# W9 GitOps Lab - Hướng Dẫn Thực Hành

## Tổng Quan
Lab thực hành GitOps với ArgoCD - từ cơ bản đến nâng cao

## Chuẩn Bị

### Yêu Cầu
- ✅ Docker Desktop
- ✅ kubectl
- ✅ minikube
- ✅ git
- ✅ GitHub account + repo trống (tên `gitops`)

### Cài Đặt Tools

```bash
# Check versions
docker --version
kubectl version --client
minikube version
git --version

# Nếu chưa cài minikube:
# Windows: choco install minikube
# hoặc download từ https://minikube.sigs.k8s.io/docs/start/
```

## Các Lab

### Lab 0: Dựng Cụm + App + Git ✅
**Mục tiêu:** Tạo Kubernetes cluster, viết app đơn giản, push lên Git

**Thời gian:** 15 phút

**Các bước:**
1. Tạo minikube cluster
2. Tạo repo GitHub `gitops`
3. Viết manifest `k8s/web.yaml`
4. Push lên Git (CHƯA apply vào cụm)

### Lab 1: Cài ArgoCD 🔧
**Mục tiêu:** Cài đặt ArgoCD vào cluster

**Thời gian:** 10 phút

**Các bước:**
1. Cài ArgoCD vào namespace `argocd`
2. Expose ArgoCD UI
3. Login vào UI

### Lab 2: Tạo Application 🚀
**Mục tiêu:** Tạo ArgoCD Application để sync từ Git

**Thời gian:** 15 phút

**Các bước:**
1. Tạo file `argocd/apps/web.yaml`
2. Apply Application
3. Kiểm tra sync status

### Lab 3: Sync & Self-Heal 🔄
**Mục tiêu:** Test auto-sync và self-healing

**Thời gian:** 10 phút

**Các bước:**
1. Đổi replicas qua Git → auto sync
2. Đổi trực tiếp kubectl → ArgoCD sửa lại

### Lab 4: Rollback ⏮️
**Mục tiêu:** Rollback bằng Git

**Thời gian:** 10 phút

**Các bước:**
1. Deploy version có lỗi
2. `git revert` để rollback
3. Verify rollback thành công

### Lab 5: App-of-Apps 📦
**Mục tiêu:** Quản lý nhiều apps bằng 1 root app

**Thời gian:** 15 phút

**Các bước:**
1. Tạo `root` Application
2. Root quản lý thư mục `argocd/apps/`
3. Test thêm app mới

### Lab 6: Sync Waves 🌊
**Mục tiêu:** Kiểm soát thứ tự deploy

**Thời gian:** 15 phút

**Các bước:**
1. Thêm Namespace + ConfigMap
2. Gắn annotations `sync-wave`
3. Verify thứ tự deploy

### Lab 7: CI Integration 🔗
**Mục tiêu:** Tích hợp CI/CD với GitHub Actions

**Thời gian:** 20 phút

**Các bước:**
1. Tạo GitHub Actions workflow
2. Build image → push Docker Hub
3. Update manifest → ArgoCD auto sync

## Cấu Trúc Thư Mục Cuối Cùng

```
gitops/
├── k8s/
│   ├── namespace.yaml       # Lab 6
│   ├── configmap.yaml       # Lab 6
│   └── web.yaml             # Lab 0
├── argocd/
│   └── apps/
│       ├── root.yaml        # Lab 5
│       └── web.yaml         # Lab 2
└── .github/
    └── workflows/
        └── ci.yaml          # Lab 7
```

## Troubleshooting

### Minikube không start
```bash
minikube delete
minikube start --driver=docker --cpus=4 --memory=4096
```

### ArgoCD pods không Running
```bash
kubectl get pods -n argocd -w
# Đợi tất cả pods = Running (có thể mất 2-3 phút)
```

### Application OutOfSync
```bash
# Force sync
argocd app sync <app-name>

# Hoặc qua UI: click Sync button
```

### Self-heal không hoạt động
Kiểm tra Application spec có:
```yaml
spec:
  syncPolicy:
    automated:
      selfHeal: true
```

## Best Practices

1. ✅ **Commit message rõ ràng**: "feat: increase web replicas to 5"
2. ✅ **Test trên dev trước**: Tạo app dev riêng
3. ✅ **Use sync waves**: Đảm bảo dependencies deploy đúng thứ tự
4. ✅ **Monitor sync status**: Check ArgoCD UI thường xuyên
5. ✅ **Git history**: Đừng force push, dùng revert

## Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [OpenGitOps Principles](https://opengitops.dev/)
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)

---

**Tác giả:** W9 GitOps Lab  
**Phiên bản:** 1.0  
**Ngày cập nhật:** 2026-06-11
