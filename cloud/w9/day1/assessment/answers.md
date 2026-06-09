# Day 1 Assessment - Answers

## Câu 1: GitOps Fundamentals

4 Principles:

**1. Declarative**
- Mô tả desired state, không phải commands
- YAML/JSON define everything
- System tự reconcile để đạt state đó
- Quan trọng vì: Reproducible, easy to understand, no procedural knowledge needed

**2. Versioned and Immutable**
- Git là single source of truth
- Mọi change qua commits
- History đầy đủ, có thể rollback
- Quan trọng vì: Audit trail, accountability, rollback capability

**3. Pulled Automatically**
- Agent trong cluster pull từ Git
- Không push từ CI/CD
- Cluster credentials không expose
- Quan trọng vì: Security, no CI/CD access to cluster, reduced attack surface

**4. Continuously Reconciled**
- Agent liên tục check và fix drift
- Self-healing khi có manual changes
- Ensure Git matches reality
- Quan trọng vì: Consistency, prevent configuration drift, automatic recovery

## Câu 2: GitHub Actions Workflow

```yaml
# .github/workflows/pr.yml
name: PR Checks

on:
  pull_request:
    branches:
      - main

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - uses: actions/setup-node@v3
        with:
          node-version: 18
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run tests
        run: npm test
      
      - name: Lint
        run: npm run lint
  
  terraform-plan:
    runs-on: ubuntu-latest
    needs: test
    steps:
      - uses: actions/checkout@v3
      
      - uses: hashicorp/setup-terraform@v2
      
      - name: Terraform Init
        run: terraform init
        working-directory: ./terraform
      
      - name: Terraform Plan
        id: plan
        run: terraform plan -no-color -out=tfplan
        working-directory: ./terraform
      
      - name: Comment PR
        uses: actions/github-script@v6
        with:
          script: |
            const output = `#### Terraform Plan
            \`\`\`
            ${{ steps.plan.outputs.stdout }}
            \`\`\`
            `;
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: output
            })
```

```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches:
      - main

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - uses: docker/login-action@v2
        with:
          registry: ${{ secrets.ECR_REGISTRY }}
          username: ${{ secrets.AWS_ACCESS_KEY_ID }}
          password: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      
      - name: Build and push
        run: |
          docker build -t myapp:${{ github.sha }} .
          docker tag myapp:${{ github.sha }} ${{ secrets.ECR_REGISTRY }}/myapp:${{ github.sha }}
          docker push ${{ secrets.ECR_REGISTRY }}/myapp:${{ github.sha }}
      
      - name: Update GitOps repo
        run: |
          git clone https://github.com/company/gitops-repo
          cd gitops-repo
          sed -i "s|image:.*|image: ${{ secrets.ECR_REGISTRY }}/myapp:${{ github.sha }}|" manifests/deployment.yaml
          git config user.name "GitHub Actions"
          git config user.email "actions@github.com"
          git add manifests/deployment.yaml
          git commit -m "Update image to ${{ github.sha }}"
          git push https://${{ secrets.GITOPS_TOKEN }}@github.com/company/gitops-repo
  
  deploy-prod:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://myapp.com
    steps:
      - name: Trigger ArgoCD sync
        run: |
          argocd app sync myapp --force
      
      - name: Wait for sync
        run: |
          argocd app wait myapp --health
      
      - name: Notify Slack
        uses: slackapi/slack-github-action@v1
        with:
          webhook-url: ${{ secrets.SLACK_WEBHOOK }}
          payload: |
            {
              "text": "Deployed myapp:${{ github.sha }} to production",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*Deploy Success*\nCommit: ${{ github.sha }}\nAuthor: ${{ github.actor }}"
                  }
                }
              ]
            }
```

Explanation:
- PR workflow chạy tests và plan, không apply
- Deploy workflow chỉ run khi merge vào main
- Production environment require approval (config trong Settings)
- Notify Slack sau khi deploy success
- Separation: CI builds image, updates GitOps repo. CD (ArgoCD) deploys

## Câu 3: ArgoCD vs Flux

Nên dùng ArgoCD khi:
- Team cần UI để visualize và debug
- Multi-tenancy với Projects
- SSO integration required
- Community và docs nhiều
- Rollback UI hữu ích

Nên dùng Flux khi:
- Muốn lightweight, minimal resource
- Bootstrap nhiều clusters
- Native Kubernetes approach
- Image update automation built-in
- Integration với Flagger

Có thể dùng cả hai:
- ArgoCD cho apps (UI benefits)
- Flux cho infrastructure (bootstrap, automation)

Hoặc:
- ArgoCD prod (UI, audit)
- Flux dev/staging (lightweight)

Recommendation: Start với ArgoCD vì UI giúp learning curve thấp hơn

## Câu 4: App of Apps Pattern

**Pattern:**
Tạo root Application deploy các child Applications

**Implementation:**
```
gitops-repo/
├── root-app.yaml
└── apps/
    ├── dev/
    │   ├── frontend.yaml
    │   └── backend.yaml
    ├── staging/
    │   ├── frontend.yaml
    │   └── backend.yaml
    └── prod/
        ├── frontend.yaml
        └── backend.yaml
```

root-app.yaml:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-dev
spec:
  source:
    repoURL: https://github.com/company/gitops-repo
    path: apps/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated: {}
```

**Lợi ích:**
- Bootstrap: 1 kubectl apply
- Add service: thêm file trong apps/, không cần kubectl
- Consistent structure
- Declarative management của Applications

**Multi-environment:**
- 3 root apps: root-dev, root-staging, root-prod
- Mỗi root point tới folder tương ứng
- Apps folder có overlays cho từng env

## Câu 5: Sync Waves

```yaml
# Wave -2: Database
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database
  annotations:
    argocd.argoproj.io/sync-wave: "-2"
---
apiVersion: v1
kind: Service
metadata:
  name: database
  annotations:
    argocd.argoproj.io/sync-wave: "-2"
---
# Wave -1: Backend API
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
spec:
  template:
    spec:
      initContainers:
      - name: wait-db
        image: busybox
        command: ['sh', '-c', 'until nc -z database 5432; do sleep 1; done']
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
---
# Wave 0: Frontend
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  annotations:
    argocd.argoproj.io/sync-wave: "0"
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  annotations:
    argocd.argoproj.io/sync-wave: "0"
---
# Wave 1: Monitoring
apiVersion: v1
kind: ServiceMonitor
metadata:
  name: app-metrics
  annotations:
    argocd.argoproj.io/sync-wave: "1"
```

ArgoCD sẽ deploy theo thứ tự: Database → Backend → Frontend → Monitoring

## Câu 6: Rollback Scenario

**Scenario A: Có laptop và VPN**

Steps:
1. Confirm issue
```bash
kubectl get pods
kubectl logs deployment/myapp --tail=100
```

2. Git revert
```bash
cd gitops-repo
git log --oneline
git revert abc123  # commit của v1.3.0
git push
```

3. Wait ArgoCD sync hoặc force
```bash
argocd app sync myapp --force
```

4. Verify
```bash
kubectl rollout status deployment/myapp
curl http://myapp.com/health
```

5. Communication
```
Slack: "Rolling back myapp to v1.2.0 due to high error rate. ETA 2 minutes."
```

**Scenario B: Chỉ có phone**

Steps:
1. kubectl từ phone (Termux hoặc app)
```bash
kubectl rollout undo deployment/myapp
```

2. Verify
```bash
kubectl get pods
```

3. Communication ngay
```
Slack: "Emergency rollback via kubectl. Will fix Git when back to laptop."
```

4. Khi có laptop, fix Git
```bash
git revert <bad-commit>
git push
argocd app sync myapp  # Confirm Git matches cluster
```

Prevent drift:
- Disable ArgoCD selfHeal temporarily
- Fix Git ASAP
- Document trong incident ticket

## Câu 7: CI/CD Pipeline Design

```
Developer Push Code
    ↓
GitHub Actions CI Triggered
    ↓
┌─────────────────────────────┐
│ Stage 1: Code Quality       │
│ - Checkout code             │
│ - Lint (ESLint)             │
│ - Unit tests (Jest)         │
│ - Code coverage             │
└─────────────────────────────┘
    ↓
┌─────────────────────────────┐
│ Stage 2: Security           │
│ - Dependency scan (npm audit)│
│ - SAST (Snyk)               │
│ - License check             │
└─────────────────────────────┘
    ↓
┌─────────────────────────────┐
│ Stage 3: Build              │
│ - Build app (npm build)     │
│ - Build Docker image        │
│ - Tag: SHA + latest         │
└─────────────────────────────┘
    ↓
┌─────────────────────────────┐
│ Stage 4: Container Security │
│ - Trivy scan image          │
│ - Check base image updates  │
└─────────────────────────────┘
    ↓
┌─────────────────────────────┐
│ Stage 5: Push               │
│ - Login to ECR              │
│ - Push image                │
│ - Sign image (cosign)       │
└─────────────────────────────┘
    ↓
┌─────────────────────────────┐
│ Stage 6: Update GitOps      │
│ - Clone gitops-repo         │
│ - Update image tag          │
│ - Commit + push             │
└─────────────────────────────┘
    ↓
ArgoCD Detects Change
    ↓
ArgoCD Syncs to Cluster
    ↓
Health Checks Pass
    ↓
Slack Notification
```

Explanation:
- Fail fast: Lint và test trước, don't build nếu fail
- Security early: Scan trước khi push image
- Separation: CI build, CD (ArgoCD) deploy
- Traceability: Image tag = Git SHA
- Notification: Team biết deploy status

## Câu 8: Security

**Sealed Secrets:**
- Encrypt secrets locally
- Commit encrypted version vào Git
- Controller trong cluster decrypt
- Pros: Simple, Git-friendly
- Cons: Key rotation phức tạp

```bash
# Create sealed secret
kubectl create secret generic mysecret --from-literal=password=123 --dry-run=client -o yaml | \
  kubeseal -o yaml > sealed-secret.yaml

# Commit sealed-secret.yaml
git add sealed-secret.yaml
git commit -m "add secret"
```

**External Secrets Operator:**
- Secrets store ở Vault/AWS Secrets Manager
- Operator sync vào cluster
- Pros: Centralized, rotation dễ
- Cons: Dependency external service

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: mysecret
spec:
  secretStoreRef:
    name: aws-secrets-manager
  target:
    name: mysecret
  data:
  - secretKey: password
    remoteRef:
      key: /prod/myapp/password
```

**ArgoCD Access:**
- ArgoCD runs trong cluster, có access Secrets
- Use RBAC limit which apps access which secrets
- Secrets không show trong UI (redacted)

**Best Practices:**
- Never commit plain secrets
- Rotate secrets regularly
- Use separate secrets per environment
- Audit secret access
- Encrypt etcd at rest

## Câu 9: Troubleshooting

**Debug Steps:**

1. Check Application status
```bash
argocd app get myapp
```

2. Check sync status
```bash
kubectl get application myapp -n argocd -o yaml
```

3. Check events
```bash
kubectl get events -n argocd --sort-by='.lastTimestamp'
```

4. Check logs
```bash
kubectl logs -n argocd deployment/argocd-application-controller
kubectl logs -n argocd deployment/argocd-repo-server
```

**Common Causes:**

1. RBAC issues
   - ArgoCD ServiceAccount thiếu permissions
   - Fix: Grant needed permissions

2. Health check fail
   - Resource không healthy theo ArgoCD
   - Fix: Check resource logs, adjust health check

3. Sync hook stuck
   - PreSync Job không complete
   - Fix: Check Job logs, adjust timeout

4. Resource dependencies
   - Resource cần CRD chưa installed
   - Fix: Use sync waves

**Prevention:**

- Test changes trong dev cluster trước
- Use sync waves cho dependencies
- Set proper timeouts
- Monitor ArgoCD metrics
- Regular RBAC audits

## Câu 10: Real-world Scenario

**Repo Structure:**
```
gitops-infra/
├── clusters/
│   ├── dev/
│   ├── staging/
│   └── prod/
│       ├── us/
│       ├── eu/
│       └── asia/
└── apps/
    ├── service-a/
    │   ├── base/
    │   └── overlays/
    │       ├── dev/
    │       ├── staging/
    │       └── prod/
    ├── service-b/
    └── ...
```

**ArgoCD Projects:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: microservices
spec:
  sourceRepos:
  - 'https://github.com/company/*'
  destinations:
  - namespace: '*'
    server: https://kubernetes.default.svc
  clusterResourceWhitelist:
  - group: ''
    kind: Namespace
  namespaceResourceWhitelist:
  - group: '*'
    kind: '*'
```

**RBAC:**
```yaml
# Developers: read-only
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
data:
  policy.csv: |
    p, role:developer, applications, get, */*, allow
    p, role:developer, applications, list, */*, allow
    g, engineering-team, role:developer

# Platform team: full access
    p, role:platform, applications, *, */*, allow
    g, platform-team, role:platform
```

**Promotion Flow:**
```
1. Engineer commits to feature branch
2. PR created
3. CI runs tests
4. Review + merge to main
5. CI builds image
6. CI updates dev overlay
7. ArgoCD syncs to dev
8. QA tests in dev
9. Manual: update staging overlay
10. ArgoCD syncs to staging
11. Integration tests
12. Approval: update prod overlay
13. ArgoCD canary deploy to prod
14. Gradual rollout
```

**Disaster Recovery:**
```
1. Git repos backed up (GitHub already does)
2. ETCD backups (Velero)
3. State in Git, restore:
   - New cluster
   - Bootstrap ArgoCD
   - Apply root apps
   - Everything syncs from Git
4. RTO: < 1 hour
5. RPO: 0 (Git is source of truth)
```

Multi-region:
- Separate ArgoCD per region
- Same Git repos
- Region-specific overlays
- Cross-region replication for Secrets/Config
