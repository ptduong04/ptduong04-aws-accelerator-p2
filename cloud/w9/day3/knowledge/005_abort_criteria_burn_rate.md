# Abort Criteria và Burn Rate

## Abort Criteria (Tiêu Chí Hủy Bỏ)

Abort Criteria là các điều kiện được định nghĩa trong AnalysisTemplate để tự động hủy bỏ canary deployment khi phát hiện vấn đề.

### Tại Sao Cần Abort Criteria?

**Vấn đề:**
- Triển khai thủ công phụ thuộc vào con người phát hiện lỗi
- Có thể mất nhiều thời gian để nhận biết sự cố
- Ảnh hưởng có thể lan rộng trong lúc chờ can thiệp

**Giải pháp:**
- Tự động phát hiện và rollback
- Giảm thiểu tác động đến người dùng
- Phản ứng nhanh hơn con người

## Các Loại Abort Criteria

### 1. Failure Condition

Điều kiện thất bại rõ ràng:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: error-rate-abort
spec:
  metrics:
  - name: error-rate
    interval: 1m
    successCondition: result < 0.05      # < 5% error rate = success
    failureCondition: result >= 0.10     # >= 10% error rate = abort
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          sum(rate(http_requests_total{status=~"5.."}[5m]))
          /
          sum(rate(http_requests_total[5m]))
```

**Hành vi:**
- Nếu error rate < 5%: Success
- Nếu 5% ≤ error rate < 10%: Inconclusive (tiếp tục)
- Nếu error rate ≥ 10%: Failure (abort rollout)

### 2. Failure Limit

Số lần thất bại tối đa trước khi abort:

```yaml
metrics:
- name: latency-check
  interval: 1m
  count: 10
  failureLimit: 3  # Abort sau 3 lần đo không đạt
  successCondition: result < 500  # Latency < 500ms
  provider:
    prometheus:
      query: |
        histogram_quantile(0.95,
          sum(rate(http_request_duration_seconds_bucket[5m])) by (le)
        ) * 1000
```

**Ví dụ:**
```
Lần 1: 450ms → Success
Lần 2: 520ms → Failure (count: 1)
Lần 3: 480ms → Success
Lần 4: 550ms → Failure (count: 2)
Lần 5: 600ms → Failure (count: 3) → ABORT!
```

### 3. Consecutive Error Limit

Số lần thất bại liên tiếp:

```yaml
metrics:
- name: availability-check
  interval: 30s
  consecutiveErrorLimit: 4  # Abort sau 4 lần liên tiếp thất bại
  successCondition: result >= 0.99
  provider:
    prometheus:
      query: |
        sum(up{job="myapp"}) / count(up{job="myapp"})
```

**Khác biệt với failureLimit:**
- `failureLimit`: Tổng số lần thất bại (không cần liên tiếp)
- `consecutiveErrorLimit`: Phải liên tiếp nhau

### 4. Inconclusive Limit

Xử lý kết quả không xác định:

```yaml
metrics:
- name: error-rate
  interval: 2m
  inconclusiveLimit: 2  # Fail sau 2 lần inconclusive
  successCondition: result < 0.05
  failureCondition: result >= 0.10
  provider:
    prometheus:
      query: |
        sum(rate(http_requests_total{status=~"5.."}[5m]))
        /
        sum(rate(http_requests_total[5m]))
```

**Kết quả inconclusive khi:**
- Không đạt successCondition
- Không đạt failureCondition
- Query trả về NaN hoặc null

## Burn Rate

### Burn Rate là gì?

**Định nghĩa:** Burn Rate là tốc độ mà service level objective (SLO) của bạn đang bị vi phạm.

**Công thức:**
```
Burn Rate = Error Rate / Error Budget Rate
```

**Ví dụ:**
- SLO: 99.9% uptime (Error Budget: 0.1%)
- Error Rate hiện tại: 0.5%
- Burn Rate = 0.5% / 0.1% = 5x

→ Đang tiêu thụ error budget với tốc độ gấp 5 lần

### Tại Sao Burn Rate Quan Trọng?

1. **Phát hiện sớm**: Nhận biết vấn đề trước khi hết error budget
2. **Mức độ nghiêm trọng**: Burn rate cao = vấn đề nghiêm trọng
3. **Quyết định triển khai**: Nên tiếp tục hay abort?

### SLO và Error Budget

**Service Level Objective (SLO):**
- Mục tiêu về độ tin cậy của service
- Ví dụ: 99.9% requests thành công

**Error Budget:**
- Phần trăm lỗi được phép
- 99.9% SLO → 0.1% error budget
- 99.95% SLO → 0.05% error budget

**Cách tính Error Budget:**
```
Error Budget = 100% - SLO
```

### Tính Toán Burn Rate

#### 1. Short-term Burn Rate (Ngắn hạn)

Đo lường trong 5-10 phút:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: short-term-burn-rate
spec:
  args:
  - name: slo
    value: "0.999"  # 99.9% SLO
  metrics:
  - name: burn-rate-5m
    interval: 1m
    count: 5
    successCondition: result < 10  # Burn rate < 10x
    failureCondition: result >= 14 # Burn rate >= 14x = critical
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          (
            sum(rate(http_requests_total{status=~"5.."}[5m]))
            /
            sum(rate(http_requests_total[5m]))
          )
          /
          (1 - {{args.slo}})
```

**Giải thích:**
- Tính error rate trong 5 phút
- Chia cho error budget (1 - 0.999 = 0.001)
- Nếu burn rate ≥ 14x → Abort ngay

#### 2. Long-term Burn Rate (Dài hạn)

Đo lường trong 1 giờ:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: long-term-burn-rate
spec:
  args:
  - name: slo
    value: "0.999"
  metrics:
  - name: burn-rate-1h
    interval: 5m
    count: 6  # 6 measurements over 30 minutes
    successCondition: result < 2  # Burn rate < 2x
    failureCondition: result >= 3 # Burn rate >= 3x
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          (
            sum(rate(http_requests_total{status=~"5.."}[1h]))
            /
            sum(rate(http_requests_total[1h]))
          )
          /
          (1 - {{args.slo}})
```

### Multi-Window Burn Rate

Kết hợp nhiều time window để giảm false positives:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: multi-window-burn-rate
spec:
  args:
  - name: service-name
  - name: slo
    value: "0.999"
  
  metrics:
  # Fast burn (5 minutes window)
  - name: fast-burn
    interval: 1m
    failureLimit: 2
    successCondition: result < 14
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          (
            sum(rate(http_requests_total{job="{{args.service-name}}",status=~"5.."}[5m]))
            /
            sum(rate(http_requests_total{job="{{args.service-name}}"}[5m]))
          ) / (1 - {{args.slo}})
  
  # Slow burn (1 hour window)
  - name: slow-burn
    interval: 5m
    failureLimit: 2
    successCondition: result < 3
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          (
            sum(rate(http_requests_total{job="{{args.service-name}}",status=~"5.."}[1h]))
            /
            sum(rate(http_requests_total{job="{{args.service-name}}"}[1h]))
          ) / (1 - {{args.slo}})
```

## Google SRE Burn Rate Thresholds

Theo Google SRE Workbook:

| Time Window | Burn Rate Threshold | Hành động |
|-------------|---------------------|-----------|
| 1 giờ | ≥ 14.4x | Alert ngay + Abort |
| 6 giờ | ≥ 6x | Alert + Cân nhắc abort |
| 24 giờ | ≥ 3x | Warning |
| 72 giờ | ≥ 1x | Monitor |

**Giải thích:**
- **14.4x trong 1h**: Sẽ hết error budget trong 3 ngày (30 ngày / 14.4 ≈ 2.08 ngày)
- **6x trong 6h**: Sẽ hết error budget trong 5 ngày
- **3x trong 24h**: Sẽ hết error budget trong 10 ngày

## Ví Dụ Thực Tế: Comprehensive Analysis

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: production-canary-validation
spec:
  args:
  - name: service-name
  - name: slo
    value: "0.999"  # 99.9%
  
  metrics:
  # 1. Error Rate Check
  - name: error-rate
    interval: 1m
    count: 5
    failureLimit: 2
    successCondition: result < 0.05      # < 5%
    failureCondition: result >= 0.10     # >= 10% = abort
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          sum(rate(http_requests_total{job="{{args.service-name}}",status=~"5.."}[5m]))
          /
          sum(rate(http_requests_total{job="{{args.service-name}}"}[5m]))
  
  # 2. Fast Burn Rate (critical)
  - name: burn-rate-fast
    interval: 1m
    consecutiveErrorLimit: 3
    successCondition: result < 14
    failureCondition: result >= 20  # Critical burn
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          (
            sum(rate(http_requests_total{job="{{args.service-name}}",status=~"5.."}[5m]))
            /
            sum(rate(http_requests_total{job="{{args.service-name}}"}[5m]))
          ) / (1 - {{args.slo}})
  
  # 3. Slow Burn Rate (warning)
  - name: burn-rate-slow
    interval: 5m
    failureLimit: 2
    successCondition: result < 3
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          (
            sum(rate(http_requests_total{job="{{args.service-name}}",status=~"5.."}[1h]))
            /
            sum(rate(http_requests_total{job="{{args.service-name}}"}[1h]))
          ) / (1 - {{args.slo}})
  
  # 4. Latency P95
  - name: latency-p95
    interval: 2m
    failureLimit: 3
    successCondition: result < 500  # < 500ms
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          histogram_quantile(0.95,
            sum(rate(http_request_duration_seconds_bucket{job="{{args.service-name}}"}[5m])) by (le)
          ) * 1000
  
  # 5. Request Rate (ensure traffic is flowing)
  - name: request-rate
    interval: 1m
    successCondition: result > 10  # At least 10 RPS
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          sum(rate(http_requests_total{job="{{args.service-name}}"}[1m]))
```

## Sử Dụng Trong Rollout

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: myapp
spec:
  replicas: 10
  strategy:
    canary:
      trafficRouting:
        istio:
          virtualService:
            name: myapp-vsvc
      
      # Background analysis - chạy liên tục
      analysis:
        templates:
        - templateName: production-canary-validation
        startingStep: 1
        args:
        - name: service-name
          value: myapp
        - name: slo
          value: "0.999"
      
      steps:
      - setWeight: 10
      - pause: {duration: 5m}
      
      - setWeight: 25
      - pause: {duration: 10m}
      
      - setWeight: 50
      - pause: {duration: 15m}
      
      - setWeight: 75
      - pause: {duration: 10m}
      
      # Manual approval before full rollout
      - pause: {}
```

## Best Practices

### 1. Chọn SLO Phù Hợp

```
99.9%   = 43.8 phút downtime/tháng
99.95%  = 21.9 phút downtime/tháng
99.99%  = 4.38 phút downtime/tháng
99.999% = 26.3 giây downtime/tháng
```

### 2. Kết Hợp Nhiều Metrics

Không chỉ dựa vào 1 metric:
- Error rate
- Latency (P50, P95, P99)
- Request rate
- Burn rate

### 3. Multiple Time Windows

- **Fast window (1-5m)**: Phát hiện vấn đề nghiêm trọng
- **Slow window (30m-1h)**: Xu hướng dài hạn

### 4. Set Thresholds Hợp Lý

- `successCondition`: Điều kiện lý tưởng
- `failureCondition`: Điều kiện không thể chấp nhận được
- Có vùng "inconclusive" ở giữa

### 5. Testing Analysis Templates

Test trước khi production:

```bash
# Tạo manual AnalysisRun
kubectl apply -f test-analysisrun.yaml

# Watch kết quả
kubectl get analysisrun test-run -w

# Xem chi tiết
kubectl describe analysisrun test-run
```

## Monitoring và Alerting

### Prometheus Alerts cho Burn Rate

```yaml
groups:
- name: burn-rate-alerts
  rules:
  - alert: HighBurnRate
    expr: |
      (
        sum(rate(http_requests_total{status=~"5.."}[5m]))
        /
        sum(rate(http_requests_total[5m]))
      ) / 0.001 > 14
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "High burn rate detected"
      description: "Burn rate is {{ $value }}x, consuming error budget rapidly"
  
  - alert: ModerateBurnRate
    expr: |
      (
        sum(rate(http_requests_total{status=~"5.."}[1h]))
        /
        sum(rate(http_requests_total[1h]))
      ) / 0.001 > 3
    for: 10m
    labels:
      severity: warning
```

---

**Tham khảo:**
- [Google SRE Workbook - Alerting on SLOs](https://sre.google/workbook/alerting-on-slos/)
- [Argo Rollouts Analysis](https://argoproj.github.io/argo-rollouts/features/analysis/)
