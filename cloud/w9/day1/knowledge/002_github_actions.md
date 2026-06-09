# GitHub Actions

GitHub Actions là CI/CD tool của GitHub, config bằng YAML file trong .github/workflows/

## Plan on Pull Request

Khi tạo pull request, workflow sẽ chạy terraform plan hoặc kubectl diff để show changes. Điều này giúp reviewer biết sẽ thay đổi gì trước khi merge.

```yaml
name: Plan

on:
  pull_request:
    branches:
      - main

jobs:
  plan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup kubectl
        uses: azure/setup-kubectl@v3
      
      - name: Show diff
        run: kubectl diff -f manifests/
      
      - name: Comment PR
        uses: actions/github-script@v6
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: 'Terraform plan output here'
            })
```

Cái này rất hữu ích vì reviewer có thể thấy trước impact của changes mà không cần run locally

## Apply on Merge

Khi PR được merge vào main, workflow khác sẽ tự động apply changes lên cluster

```yaml
name: Deploy

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ap-southeast-1
      
      - name: Update kubeconfig
        run: aws eks update-kubeconfig --name my-cluster
      
      - name: Deploy
        run: kubectl apply -f manifests/
```

Pattern này đảm bảo chỉ có code đã review mới được deploy

## Workflow Structure

Cấu trúc file workflow:

```yaml
name: Workflow name

on:
  push:
    branches: [main]
    paths:
      - 'app/**'

jobs:
  job-name:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Run command
        run: echo "Hello"
      
      - name: Use action
        uses: some/action@v1
        with:
          parameter: value
```

## Common Actions

Setup tools:
- actions/checkout@v3 - Clone repo
- actions/setup-node@v3 - Setup Node.js
- actions/setup-python@v4 - Setup Python
- azure/setup-kubectl@v3 - Setup kubectl

Cloud credentials:
- aws-actions/configure-aws-credentials@v2
- azure/login@v1
- google-github-actions/auth@v1

Docker:
- docker/build-push-action@v4
- docker/login-action@v2

## Secrets Management

Secrets không commit vào Git, store trong GitHub Settings

```yaml
steps:
  - name: Login to registry
    uses: docker/login-action@v2
    with:
      username: ${{ secrets.DOCKER_USERNAME }}
      password: ${{ secrets.DOCKER_PASSWORD }}
```

Types of secrets:
- Repository secrets: Chỉ cho 1 repo
- Organization secrets: Share across repos
- Environment secrets: Per environment (prod, staging)

## Matrix Builds

Test trên nhiều versions:

```yaml
jobs:
  test:
    strategy:
      matrix:
        node-version: [14, 16, 18]
        os: [ubuntu-latest, windows-latest]
    
    runs-on: ${{ matrix.os }}
    
    steps:
      - uses: actions/setup-node@v3
        with:
          node-version: ${{ matrix.node-version }}
      
      - run: npm test
```

## Caching

Speed up workflows bằng cache:

```yaml
steps:
  - uses: actions/cache@v3
    with:
      path: ~/.npm
      key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
      restore-keys: |
        ${{ runner.os }}-node-
  
  - run: npm ci
```

Cache sẽ restore nếu package-lock.json không đổi

## Artifacts

Share data giữa jobs hoặc download sau workflow:

```yaml
jobs:
  build:
    steps:
      - run: npm run build
      
      - uses: actions/upload-artifact@v3
        with:
          name: dist
          path: dist/
  
  deploy:
    needs: build
    steps:
      - uses: actions/download-artifact@v3
        with:
          name: dist
      
      - run: aws s3 sync dist/ s3://bucket/
```

## Environment Protection

Require approval trước khi deploy production:

```yaml
jobs:
  deploy-prod:
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://myapp.com
    
    steps:
      - run: kubectl apply -f prod/
```

Trong Settings > Environments > production, set required reviewers
