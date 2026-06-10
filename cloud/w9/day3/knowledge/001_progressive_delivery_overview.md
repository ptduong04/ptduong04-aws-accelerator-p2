# Tổng Quan Progressive Delivery

## Progressive Delivery là gì?

Progressive Delivery là sự phát triển của Continuous Delivery, tập trung vào việc giảm thiểu rủi ro bằng cách triển khai thay đổi dần dần cho một nhóm người dùng nhỏ trước khi đưa ra cho tất cả mọi người.

### Khái Niệm Chính

**Traditional Deployment vs Progressive Delivery:**
- **Traditional**: Triển khai tất cả hoặc không (Blue/Green, Recreate)
- **Progressive**: Triển khai dần dần với xác thực liên tục (Canary, A/B Testing)

### Lợi Ích

1. **Giảm thiểu rủi ro**: Sự cố chỉ ảnh hưởng đến một phần nhỏ người dùng
2. **Phản hồi nhanh hơn**: Phát hiện sớm các vấn đề
3. **Kiểm soát triển khai**: Khả năng tạm dừng/hủy bỏ dựa trên metrics
4. **Kiểm thử trên production**: Xác thực với người dùng thực trước khi triển khai đầy đủ

## Các Chiến Lược Progressive Delivery

### 1. Canary Deployment

Chuyển dần traffic từ phiên bản cũ sang phiên bản mới trong khi giám sát metrics.

**Luồng điển hình:**
```
Old: 100% → 90% → 75% → 50% → 25% → 0%
New:   0% → 10% → 25% → 50% → 75% → 100%
```

**Trường hợp sử dụng:**
- Thay đổi có rủi ro cao
- Tính năng mới cần xác thực
- Ứng dụng quan trọng về hiệu năng

### 2. Blue/Green Deployment

Hai môi trường giống hệt nhau, chuyển traffic ngay lập tức sau khi xác thực.

**Luồng:**
```
Blue (v1) ← 100% traffic
Green (v2) ← 0% traffic (testing)
→ Chuyển đổi →
Blue (v1) ← 0% traffic (standby)
Green (v2) ← 100% traffic
```

### 3. A/B Testing

Định tuyến các phân khúc người dùng cụ thể đến các phiên bản khác nhau để thử nghiệm.

**Tiêu chí định tuyến:**
- Thông tin nhân khẩu học người dùng
- Vị trí địa lý
- Loại thiết bị
- Định tuyến dựa trên header

### 4. Feature Flags

Kiểm soát tính khả dụng của tính năng mà không cần triển khai.

**Lợi ích:**
- Rollback tức thì
- Triển khai có chọn lọc
- Kiểm thử trên production

## Tại Sao Cần Argo Rollouts?

Kubernetes native progressive delivery controller mở rộng khả năng của Deployment.

### Vấn Đề với Standard Deployments

1. **Không kiểm soát traffic**: Không thể chuyển traffic dần dần
2. **Rollback hạn chế**: Chỉ dựa trên revision, không dựa trên metrics
3. **Không có phân tích**: Không thể tự động xác thực deployments
4. **Quy trình thủ công**: Yêu cầu can thiệp của con người

### Giải Pháp của Argo Rollouts

✅ **Canary/Blue-Green tự động**
✅ **Traffic Shaping** (Istio, Nginx, ALB, SMI)
✅ **Phân tích Metrics** (Prometheus, Datadog, New Relic)
✅ **Rollback tự động** dựa trên metrics
✅ **Progressive Promotion** với pause/resume

## Các Thành Phần Chính

### 1. Rollout CRD (Custom Resource Definition)

Thay thế Kubernetes Deployment với các khả năng nâng cao:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: myapp
spec:
  strategy:
    canary:
      steps:
      - setWeight: 20
      - pause: {duration: 5m}
      - setWeight: 50
      - pause: {duration: 10m}
```

### 2. AnalysisTemplate

Định nghĩa các truy vấn metrics và tiêu chí thành công:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: error-rate-check
spec:
  metrics:
  - name: error-rate
    provider:
      prometheus:
        query: |
          rate(http_requests_total{status=~"5.."}[5m])
    successCondition: result < 0.05
```

### 3. AnalysisRun

Instance của analysis được thực thi trong quá trình rollout:
- Tự động tạo bởi Rollout
- Có thể kích hoạt thủ công
- Báo cáo trạng thái pass/fail/error

### 4. Tích Hợp Traffic Management

Argo Rollouts tích hợp với:
- **Service Mesh**: Istio, Linkerd, SMI
- **Ingress**: Nginx, ALB, Traefik
- **Gateway API**: Standard Kubernetes Gateway

## So Sánh: Các Chiến Lược Triển Khai GitOps

| Chiến lược | Rủi ro | Tốc độ | Độ phức tạp | Trường hợp sử dụng |
|----------|------|-------|------------|----------|
| **Recreate** | Cao | Nhanh | Thấp | Môi trường Dev/Test |
| **Rolling Update** | Trung bình | Trung bình | Thấp | Ứng dụng không quan trọng |
| **Blue/Green** | Thấp | Nhanh | Trung bình | Cần rollback nhanh |
| **Canary** | Rất thấp | Chậm | Cao | Ứng dụng production quan trọng |

## Các Bước Tiếp Theo

1. Hiểu kiến trúc Argo Rollouts
2. Triển khai Canary deployments
3. Tạo AnalysisTemplates với Prometheus
4. Cấu hình abort criteria
5. Tính toán và giám sát burn rate

---

**Tham khảo:**
- [Argo Rollouts Documentation](https://argoproj.github.io/argo-rollouts/)
- [Progressive Delivery Explained](https://www.weave.works/blog/progressive-delivery)
