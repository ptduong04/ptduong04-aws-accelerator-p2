# GitOps Overview

## GitOps là gì

GitOps về cơ bản là dùng Git làm source of truth cho cả infrastructure lẫn application. Thay vì ssh vào server rồi kubectl apply tay, giờ mọi thứ đều qua Git.

Workflow cơ bản:
- Code thay đổi push lên Git
- CI/CD tự động chạy
- Cluster tự sync theo Git
- Nếu ai đó kubectl edit trực tiếp thì sẽ bị revert lại theo Git

Lợi ích chính:
- Audit trail đầy đủ, biết ai thay đổi gì lúc nào
- Rollback dễ, chỉ cần git revert
- Disaster recovery đơn giản, clone repo là có lại hết
- Review changes qua pull request trước khi apply

## Principles

GitOps có 4 principles chính:

1. Declarative
   - Mô tả desired state, không phải commands
   - YAML manifests define everything
   - System reconcile để đạt state đó

2. Versioned and Immutable
   - Git history là single source of truth
   - Mọi change đều qua commit
   - Có thể rollback bất kỳ lúc nào

3. Pulled Automatically
   - Agent trong cluster pull từ Git
   - Không push từ CI/CD vào cluster
   - More secure, không expose cluster credentials

4. Continuously Reconciled
   - Agent liên tục check Git vs cluster state
   - Tự động fix drift (manual changes)
   - Self-healing capability

## GitOps vs Traditional CI/CD

Traditional approach:
```
CI/CD pipeline → kubectl apply → Cluster
```
- Pipeline có full access tới cluster
- Security risk nếu pipeline compromised
- Không có single source of truth

GitOps approach:
```
CI builds image → Update Git → Agent pulls → Cluster
```
- Cluster credentials không expose
- Git là single source of truth
- Clear separation: CI builds, CD deploys

## Why GitOps

Trước khi có GitOps, deploy thường như này:
- Dev viết code
- CI build và test
- CI/CD script kubectl apply vào cluster
- Không biết cluster state thực tế như nào
- Manual changes không tracked

Vấn đề:
- Configuration drift (Git khác với cluster)
- Không có audit trail cho manual changes
- Khó rollback
- Không reproducible

GitOps giải quyết bằng cách:
- Git là single source of truth
- Cluster state luôn match Git
- Mọi change đều có Git history
- Rollback = git revert
- Reproducible: clone repo là có lại infrastructure
