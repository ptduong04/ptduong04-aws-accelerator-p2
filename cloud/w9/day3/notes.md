# Day 3: Progressive Delivery với Argo Rollouts

## Tổng quan
Tìm hiểu về Progressive Delivery (Canary Deployment) sử dụng Argo Rollouts, tích hợp với Prometheus để phân tích metrics, và cấu hình abort criteria dựa trên burn rate.

## Nội dung chính

### 1. Progressive Delivery
- Canary Deployment strategy
- Blue/Green deployment
- A/B Testing
- So sánh với traditional deployment

### 2. Argo Rollouts
- Architecture và components
- Rollout CRD
- Traffic management (Istio, Nginx, ALB)
- kubectl plugin

### 3. AnalysisTemplate với Prometheus
- Cấu hình Prometheus queries
- Error rate monitoring
- Latency checks (P95, P99)
- Resource usage metrics

### 4. Abort Criteria
- Failure conditions
- Failure limits
- Consecutive error limits
- Inconclusive handling

### 5. Burn Rate
- SLO và Error Budget
- Tính toán burn rate
- Multi-window burn rate
- Google SRE thresholds

## Các file knowledge

1. `001_progressive_delivery_overview.md` - Tổng quan Progressive Delivery
2. `002_argo_rollouts_architecture.md` - Kiến trúc Argo Rollouts
3. `003_rollout_crd_canary.md` - Rollout CRD và Canary strategy
4. `004_analysis_template_prometheus.md` - AnalysisTemplate với Prometheus
5. `005_abort_criteria_burn_rate.md` - Abort criteria và Burn rate

## Key takeaways

✅ Progressive Delivery giảm rủi ro bằng cách triển khai dần dần
✅ Argo Rollouts cung cấp automated canary với metric-based rollback
✅ AnalysisTemplate cho phép định nghĩa success/failure criteria
✅ Burn rate giúp phát hiện sớm vi phạm SLO
✅ Multi-window monitoring giảm false positives

## Ví dụ thực tế

### Canary Deployment Flow
```
1. Deploy 10% traffic → Analyze 5m → Success
2. Deploy 25% traffic → Analyze 10m → Success
3. Deploy 50% traffic → Analyze 15m → Success
4. Manual approval
5. Deploy 100% → Completed
```

### Abort Scenario
```
1. Deploy 10% → Error rate: 8% → Continue (< threshold)
2. Deploy 25% → Error rate: 12% → ABORT! (> 10% threshold)
3. Automatic rollback to stable version
```

## Best Practices

1. **Start small**: Bắt đầu với traffic % nhỏ (5-10%)
2. **Multiple metrics**: Không chỉ dựa vào 1 metric
3. **Progressive steps**: Tăng traffic dần dần
4. **Manual gate**: Có pause trước 100% traffic
5. **Monitor burn rate**: Sử dụng multi-window để phát hiện sớm

## Commands hữu ích

```bash
# Install Argo Rollouts
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Install kubectl plugin
kubectl argo rollouts version

# Watch rollout
kubectl argo rollouts get rollout <name> --watch

# Promote rollout
kubectl argo rollouts promote <name>

# Abort rollout
kubectl argo rollouts abort <name>

# Dashboard
kubectl argo rollouts dashboard
```

## Đọc thêm

- [Argo Rollouts Documentation](https://argoproj.github.io/argo-rollouts/)
- [Google SRE Workbook](https://sre.google/workbook/)
- [Progressive Delivery Guide](https://www.weave.works/blog/progressive-delivery)
