# Day 1 Assessment - GitOps và CI/CD

## Câu 1: GitOps Fundamentals

GitOps có 4 principles chính. Hãy giải thích từng principle và tại sao chúng quan trọng?

## Câu 2: GitHub Actions Workflow

Thiết kế workflow cho scenario sau:
- Pull Request tạo ra phải chạy tests và show Terraform plan
- Merge vào main phải tự động apply changes
- Production deploy cần approval trước khi chạy
- Notify Slack khi deploy xong

Viết YAML config và giải thích từng bước.

## Câu 3: ArgoCD vs Flux

Công ty đang chọn GitOps tool. CTO hỏi:
- "Nên dùng ArgoCD hay Flux?"
- "Có thể dùng cả hai không?"

Trả lời dựa trên use cases cụ thể và trade-offs.

## Câu 4: App of Apps Pattern

Bạn có 10 microservices cần deploy. Explain:
- App of Apps pattern là gì?
- Làm thế nào implement?
- Lợi ích so với tạo từng Application manual?
- Structure folder như thế nào cho dev/staging/prod?

## Câu 5: Sync Waves

Application có dependencies:
1. Database phải start trước
2. Backend API cần database ready
3. Frontend cần backend ready
4. Monitoring cần tất cả running

Làm thế nào dùng sync waves để handle dependencies này?
Viết example manifests với annotations.

## Câu 6: Rollback Scenario

Production app v1.3.0 deployed 10 phút trước, bây giờ error rate tăng từ 0.1% lên 5%.

Scenario A: Bạn đang ở nhà, có laptop và VPN
Scenario B: Đang đi đường, chỉ có phone và kubectl access

Với mỗi scenario:
- Làm gì đầu tiên?
- Steps rollback như thế nào?
- Làm sao prevent drift?
- Communication với team?

## Câu 7: CI/CD Pipeline Design

Design complete pipeline cho Node.js app:

Requirements:
- Code push trigger CI
- Run lint, test, security scan
- Build Docker image
- Push to ECR
- Update GitOps repo
- ArgoCD deploy

Vẽ flow chart và explain từng stage.

## Câu 8: Security

Trong GitOps workflow, secrets không được commit vào Git.

Questions:
- Làm thế nào manage secrets?
- Sealed Secrets vs External Secrets Operator?
- ArgoCD access secrets như thế nào?
- Best practices?

## Câu 9: Troubleshooting

ArgoCD Application stuck ở "Progressing" status.

Debug steps:
- Kiểm tra gì đầu tiên?
- Common causes?
- Làm sao fix?
- Prevent tương lai?

## Câu 10: Real-world Scenario

Team có:
- 5 microservices
- 3 environments (dev, staging, prod)
- Multi-region deployment (US, EU, Asia)
- 10 engineers commit code daily

Design complete GitOps setup:
- Repo structure?
- ArgoCD Projects?
- RBAC cho engineers?
- Promotion flow dev → staging → prod?
- Disaster recovery plan?
