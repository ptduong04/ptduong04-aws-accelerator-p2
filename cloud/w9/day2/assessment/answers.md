# Day 2 Observability - Đáp Án Chi Tiết

## Câu 1: Observability vs Monitoring

### a) Giải thích sự khác biệt giữa 2 scenarios

**Monitoring (Scenario A):**
- Biết CÓ vấn đề: Latency cao
- KHÔNG biết tại sao
- Phải đoán mò: CPU? Memory? Network?
- Debug kiểu thử-sai, mất nhiều thời gian

**Observability (Scenario B):**
- Biết CÓ vấn đề: Latency cao
- Biết CHÍNH XÁC nguyên nhân: Connection pool hết chỗ
- Biết Ở ĐÂU: Query database cụ thể nào
- Biết KHI NÀO: Bắt đầu 10:30 sáng
- Hành động trực tiếp: Tăng kích thước connection pool

Khác biệt cốt lõi:
- Monitoring: Trả lời "Cái gì bị lỗi?"
- Observability: Trả lời "Tại sao nó lỗi?"

### b) 3 trụ cột và thông tin từng cái cung cấp

**Metrics (Chỉ số đo lường):**
- Dữ liệu: Latency p95 = 2.1s, timestamp
- Mục đích: Phát hiện bất thường, hiển thị xu hướng
- Giá trị: Biết khi nào bắt đầu, mức độ nghiêm trọng

**Traces (Dấu vết request):**
- Dữ liệu: Luồng request qua các service, thời gian từng bước
- Mục đích: Xác định nút thắt cổ chai trong hệ thống phân tán
- Giá trị: Chỉ đúng database query nào gây chậm


**Logs (Nhật ký hệ thống):**
- Dữ liệu: "Connection pool exhausted: 100/100 connections"
- Mục đích: Context chi tiết, thông điệp lỗi cụ thể
- Giá trị: Giải thích nguyên nhân gốc rễ

Sức mạnh khi kết hợp: Metrics báo động → Traces định vị → Logs giải thích

### c) Tại sao monitoring không đủ

Vấn đề: Connection pool hết chỗ

Monitoring chỉ hiển thị:
- CPU 45%: Bình thường, không chỉ ra vấn đề
- Memory 60%: Bình thường  
- Latency cao: Đây là triệu chứng, không phải nguyên nhân

Thông tin thiếu:
- Không track metrics của connection pool
- Không có dấu vết request
- Không có logs chi tiết

Với monitoring, engineer phải:
1. Đoán nhiều nguyên nhân có thể
2. Check từng component một
3. Deploy code debug
4. Đợi lỗi tái hiện
5. Thời gian giải quyết: Hàng giờ

Với observability:
1. Check traces → thấy database chậm
2. Check logs → thấy pool hết chỗ
3. Fix: Tăng pool size
4. Thời gian giải quyết: Vài phút



---

## Câu 2: OpenTelemetry Architecture

### a) Đề xuất architecture sử dụng OpenTelemetry

```
┌─────────────┐      ┌──────────────┐      ┌──────────┐
│ API Gateway │─────▶│ User Service │─────▶│ Database │
└──────┬──────┘      └──────┬───────┘      └──────────┘
       │                     │
     OTel SDK            OTel SDK
       │                     │
       └─────────┬───────────┘
                 ▼
        ┌────────────────┐
        │ OTel Collector │ (Agent trên mỗi node)
        └────────┬───────┘
                 │
     ┌───────────┼───────────┐
     ▼           ▼           ▼
┌──────────┐ ┌──────┐ ┌───────┐
│Prometheus│ │ Loki │ │Jaeger │
└──────────┘ └──────┘ └───────┘
     │           │          │
     └───────────┴─────┬────┘
                       ▼
                  ┌─────────┐
                  │ Grafana │
                  └─────────┘
```

**Các components:**

1. **OTel SDK trong Applications:**
   - Thay thế Jaeger SDK và Zipkin SDK bằng OTel SDK
   - Auto-instrumentation cho HTTP, database calls
   - Export format OTLP (unified format)
   
   Thay đổi code (tối thiểu):
   ```javascript
   // Trước: Jaeger-specific
   const jaeger = require('jaeger-client');
   
   // Sau: OTel universal
   const { NodeTracerProvider } = require('@opentelemetry/sdk-trace-node');
   const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');
   ```


2. **OTel Collector:**
   - Nhận: OTLP protocol (gRPC/HTTP)
   - Xử lý: Thêm attributes, filter, batch
   - Export: Fan-out ra nhiều backends

3. **Multiple Backends:**
   - Prometheus: Lưu metrics + alerting
   - Loki: Gom logs
   - Jaeger: Lưu traces + UI để xem
   - Grafana: Visualization tất cả trong 1 chỗ

### b) Deployment Pattern: Hybrid (Agent + Gateway)

**Đề xuất: Pattern lai Agent + Gateway**

**Agent (DaemonSet):**
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: otel-agent
spec:
  template:
    spec:
      containers:
      - name: otel-collector
        image: otel/opentelemetry-collector:latest
        # Xử lý tối thiểu: nhận + forward
```

**Gateway (Deployment):**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-gateway
spec:
  replicas: 3  # Có thể scale
  template:
    spec:
      containers:
      - name: otel-collector
        # Xử lý nặng: transform, filter, export
```


**Tại sao Hybrid:**

1. **Lợi ích của Agent:**
   - Latency thấp: Apps gửi tới localhost
   - High availability: Buffer local
   - Giảm network: Xử lý trên node

2. **Lợi ích của Gateway:**
   - Xử lý tập trung: Các transforms nặng
   - Scalable: Thêm replicas độc lập
   - Tiết kiệm: Share resources

3. **Luồng đi:**
   ```
   App → Agent (local) → Gateway (central) → Backends
   ```

Agent: Nhận nhanh, xử lý tối thiểu
Gateway: Xử lý phức tạp, fan-out

### c) PromQL query để track burn rate

```promql
# Error ratio (1 - availability)
(
  sum(rate(http_requests_total{status=~"5.."}[5m]))
  /
  sum(rate(http_requests_total[5m]))
)
/
0.001  # Error budget cho SLO 99.9%
```

Giải thích:
- Tử số: Error rate trong 5 phút
- Mẫu số: Error budget (1 - 0.999 = 0.001)
- Kết quả: Burn rate multiplier (1x = bình thường, 10x = đốt nhanh)



---

## Câu 3: Prometheus Query

### a) Query tính error rate

```promql
sum(rate(http_requests_total{path="/api/users", status=~"[45].."}[5m]))
/
sum(rate(http_requests_total{path="/api/users"}[5m]))
```

Giải thích:
- `status=~"[45].."`: Regex match 4xx và 5xx
- `rate(...[5m])`: Tốc độ per-second trong 5 phút
- Chia: Phần trăm lỗi

Tính toán kết quả:
```
Errors (5xx): 600 requests
Total: 50,600 requests
Error rate: 600/50,600 = 1.18%
```

### b) Query tính P95 latency

```promql
histogram_quantile(
  0.95,
  rate(http_request_duration_seconds_bucket{path="/api/users"}[5m])
)
```

Giải thích:
- `histogram_quantile(0.95, ...)`: Tính percentile 95
- `rate(...[5m])`: Chuẩn hóa bucket counts

Tính toán kết quả:
```
Buckets:
- le="0.1": 30,000 (59%)
- le="0.5": 48,000 (95%)  ← P95 rơi vào đây
- le="1.0": 50,000 (99%)
- le="+Inf": 50,600 (100%)

P95 latency ≈ 0.5 giây
```


### c) Tại sao cần dùng rate()

**Vấn đề với counter thô:**
```promql
# SẼ SAI
sum(http_requests_total)
```

Vấn đề:
1. **Resets:** Pod restart → counter reset về 0
2. **Giá trị tuyệt đối:** 45,000 requests không có nghĩa gì nếu không có context thời gian
3. **Không so sánh được:** Windows thời gian khác cho số khác

**Giải pháp với rate():**
```promql
# ĐÚNG
rate(http_requests_total[5m])
```

Lợi ích:
1. **Xử lý resets:** Tự động phát hiện và bù trừ
2. **Per-second rate:** 150 requests/giây (có thể so sánh)
3. **Chuẩn hóa thời gian:** Cùng đơn vị dù window khác nhau

Ví dụ:
```
10:00 → counter = 1000
10:05 → counter = 1000 (pod restart!)
10:10 → counter = 1500

Không có rate(): Graph sẽ xuống 0 tại 10:05
Có rate(): Graph đều đặn, bỏ qua reset
```

rate() là thiết yếu cho counters trong production



---

## Câu 4: Loki vs Elasticsearch

### a) So sánh chiến lược indexing

**Elasticsearch:**
- **Chiến lược:** Full-text index
- **Index:** Mọi từ trong nội dung log
- **Storage:** Cao (inverted index cho toàn bộ text)
- **Tốc độ query:** Nhanh cho full-text search
- **Chi phí:** Đắt (indices lớn)

Ví dụ:
```
Log: "User 123 failed login from 192.168.1.1"
Indexed: ["User", "123", "failed", "login", "from", "192", "168", "1", "1"]
Search: "failed" → kết quả ngay lập tức
```

**Loki:**
- **Chiến lược:** Chỉ index labels
- **Index:** Chỉ labels (service, pod, namespace)
- **Storage:** Thấp (index nhỏ, nén logs)
- **Tốc độ query:** Chậm hơn cho full-text (grep qua log content)
- **Chi phí:** Rẻ (10x ít hơn ES)

Ví dụ:
```
Labels indexed: {service="api", pod="api-123", level="error"}
Log content: KHÔNG index, lưu nén
Search "failed": Grep qua logs (chậm hơn nhưng chấp nhận được)
```


### b) Đề xuất: Loki

**Lý do:**

1. **Chi phí:** 50 services × 10k logs/giây = 500k logs/giây
   - ES: ~5-10 TB/ngày với indices
   - Loki: ~1 TB/ngày với nén
   - Tiết kiệm: 80%

2. **Tích hợp:** Đã dùng Grafana
   - Loki: Tích hợp native với Grafana
   - ES: Cần Kibana hoặc plugins thêm
   - UI thống nhất với metrics + logs + traces

3. **Kubernetes-native:**
   - Loki: Build cho K8s labels (pod, namespace, container)
   - Promtail DaemonSet: Tự động discover pods
   - Extract labels từ K8s metadata

4. **Pattern query:**
   - Hầu hết queries: Filter theo service, pod, trace_id (labels)
   - Full-text search: Chấp nhận được chậm hơn
   - Trade-off: Chi phí > Tốc độ

**Khi nào dùng ES thay vì:**
- Cần full-text search cực nhanh
- Requirements query DSL phức tạp
- Compliance/legal: Phải search toàn bộ logs lịch sử
- Ngân sách không là vấn đề


### c) Chiến lược Labels cho Loki

**NÊN index làm labels:**
```
{
  service="checkout-api",      ✓ Low cardinality (50 services)
  environment="production",    ✓ Low cardinality (3-4 môi trường)
  namespace="backend",         ✓ Low cardinality (10 namespaces)
  level="error",               ✓ Low cardinality (4-5 levels)
  pod="api-123"                ✓ Medium cardinality (hàng trăm pods)
}
```

**KHÔNG NÊN index (để trong content):**
```json
{
  "user_id": "u_789",          ✗ High cardinality (hàng triệu)
  "trace_id": "abc123...",     ✗ Unique mỗi request
  "request_id": "req_456",     ✗ Unique mỗi request
  "email": "user@example.com"  ✗ High cardinality
}
```

**Tại sao:**

High cardinality labels = nhiều tổ hợp labels = index lớn

Ví dụ vấn đề:
```
{service="api", user_id="1"} → stream 1
{service="api", user_id="2"} → stream 2
...
{service="api", user_id="1000000"} → stream 1000000

Kết quả: 1 triệu streams = index khổng lồ = đắt!
```

**Best practice:**
- Labels: Giá trị có giới hạn để filter
- Content: Dữ liệu high-cardinality, search bằng grep

Pattern query:
```logql
# Filter theo label (nhanh)
{service="checkout-api", level="error"}
# Sau đó grep content (tốc độ chấp nhận được)
| json
| trace_id="abc123"
```



---

## Câu 5: Lựa chọn SLI

### a) Đề xuất SLIs user-centric

**1. Tỷ lệ thành công tìm kiếm (Search Success Rate)**
- **Góc nhìn user:** "Tôi search 'laptop' và thấy kết quả"
- **Đo lường:**
  ```
  successful_searches / total_searches
  ```
- **Tiêu chí thành công:** Trả về kết quả trong 3s, không lỗi
- **Target:** 99.5%

**2. Tỷ lệ hoàn thành checkout (Checkout Completion Rate)**
- **Góc nhìn user:** "Tôi bấm checkout và order thành công"
- **Đo lường:**
  ```
  completed_checkouts / initiated_checkouts
  ```
- **Tiêu chí thành công:** Thanh toán xử lý xong, gửi confirmation
- **Target:** 99.9% (critical path)

**3. Thời gian tải trang (Page Load Latency)**
- **Góc nhìn user:** "Trang load nhanh hay chậm?"
- **Đo lường:**
  ```
  p95_page_load_time < 2 giây
  ```
- **Tiêu chí thành công:** Render toàn bộ trang kể cả hình
- **Target:** 95% trang < 2s

**4. Tỷ lệ gửi email thành công (Email Delivery Success)**
- **Góc nhìn user:** "Tôi nhận được email xác nhận"
- **Đo lường:**
  ```
  emails_delivered / emails_sent
  ```
- **Tiêu chí thành công:** Gửi được trong 5 phút
- **Target:** 99%


### b) Tại sao không nên dùng CPU/Memory làm SLI chính

**Vấn đề 1: Không phản ánh trải nghiệm user**
```
Scenario A:
- CPU: 90% (cao!)
- Trải nghiệm user: Hoàn hảo, latency 100ms
- SLI vi phạm nhưng users hạnh phúc

Scenario B:
- CPU: 30% (thấp!)
- Trải nghiệm user: Timeout errors
- SLI đạt nhưng users không hài lòng
```

CPU/Memory là internal metrics, không tương quan với tác động lên user

**Vấn đề 2: Không actionable**
```
Alert: "CPU > 80%"
Làm gì: ???

vs

Alert: "Checkout success rate < 99.9%"
Làm gì: Điều tra payment failures, rollback deploy
```

**Vấn đề 3: Phụ thuộc platform**
```
- App Java: Memory usage cao là bình thường (JVM)
- App Go: Memory usage thấp là bình thường
- Cùng threshold SLI không work cho cả 2
```

**Cách đúng:**
- SLI: User-facing metrics (latency, errors)
- CPU/Memory: Supporting metrics để debug

Khi SLI vi phạm → check CPU/Memory để debug


### c) SLOs khác nhau cho Payment vs Search

**Payment API (Critical):**
```yaml
SLOs:
  - Availability: 99.95%  # Nghiêm ngặt hơn
    Error budget: 0.05% = 21 phút/tháng
  
  - Latency p95: 300ms    # Chặt chẽ hơn
  
  - Success rate: 99.99%  # Rất nghiêm ngặt
    (Lỗi payment = mất revenue)
```

**Search API (Quan trọng nhưng không critical):**
```yaml
SLOs:
  - Availability: 99.5%   # Thoải mái hơn
    Error budget: 0.5% = 3.6 giờ/tháng
  
  - Latency p95: 1s       # Lỏng hơn
  
  - Success rate: 99%
    (Search lỗi = UX kém, không mất revenue trực tiếp)
```

**Lý do:**

Payment API:
- Tác động trực tiếp revenue
- Lòng tin user rất quan trọng
- Đáng để tốn chi phí vận hành cao hơn
- Chấp nhận tốc độ phát triển tính năng chậm hơn

Search API:
- Tác động gián tiếp revenue
- Degradation ít nghiêm trọng hơn
- Cân bằng reliability vs velocity
- Ưu tiên iteration nhanh hơn


**Alerting khác nhau:**
```yaml
Payment API:
  - Burn rate > 5x: Page ngay lập tức
  - Budget < 50%: Freeze features

Search API:
  - Burn rate > 10x: Page
  - Budget < 25%: Freeze features
```

Chịu đựng nhiều hơn cho search, ít hơn cho payment

---

## Câu 6: Error Budget Policy

### a) Tính toán error budget

**Đề bài:**
- SLO: 99.9% availability
- Window: 30 ngày
- Hiện tại: 99.85% availability (ngày 21)

**Tính toán:**

Tổng error budget:
```
Budget = 1 - SLO = 1 - 0.999 = 0.1%
Quy ra phút = 30 ngày × 24 giờ × 60 phút × 0.001 = 43.2 phút
```

Đã tiêu tốn:
```
Tiêu tốn = 1 - 0.9985 = 0.15%
Quy ra phút = 30 ngày × 24 giờ × 60 phút × 0.0015 = 64.8 phút
```

Còn lại:
```
Còn lại = 0.1% - 0.15% = -0.05%
Quy ra phút = 43.2 - 64.8 = -21.6 phút

Budget đã hết! Vượt 21.6 phút (overspent 50%)
```

Phần trăm tiêu tốn:
```
Tiêu tốn = 0.15% / 0.1% = 150%
```


### b) Hành động team nên làm

**Trạng thái: CRITICAL - Budget đã cạn**

Hành động ngay lập tức:

1. **Freeze features hoàn toàn**
   - Không làm features mới cho đến hết tháng
   - Không thay đổi rủi ro
   - Chỉ fix bug critical

2. **Focus vào stability**
   - Review các incidents gần đây (ngày 11-15)
   - Implement biện pháp phòng ngừa
   - Tăng cường monitoring

3. **Bắt buộc post-mortem**
   - Document tất cả incidents
   - Xác định root causes
   - Action items cho tháng sau

4. **Thông báo stakeholders**
   - Inform ban quản lý về tình trạng budget
   - Giải thích tác động lên feature delivery
   - Set expectations cho 9 ngày còn lại

5. **Chuẩn bị tháng sau**
   - SLO nghiêm ngặt hơn (99.95%?) nếu cần
   - Alerting tốt hơn để catch issues sớm hơn
   - Cải thiện deployment practices


### c) Error Budget Policy

```markdown
## Error Budget Policy - Service Availability SLO 99.9%

### Tier 1: Khỏe mạnh (> 75% budget còn lại)
**Trạng thái:** XANH

**Hành động:**
- Ship features bình thường
- Review process tiêu chuẩn
- OK thử nghiệm công nghệ mới
- Nhiều deploys/ngày được phép
- Chấp nhận rủi ro có tính toán

**Deployment:**
- Tự động deployments
- Canary: 10% → 50% → 100% (30 phút)
- Rollback nếu error rate > 0.1%

**Monitoring:**
- Review SLO hàng tuần
- Tối ưu proactive

---

### Tier 2: Thận trọng (50-75% budget còn)
**Trạng thái:** VÀNG

**Hành động:**
- Chậm lại feature velocity
- Tăng requirements testing
- Code review: Cần 2+ approvals
- Focus cải thiện stability
- Hoãn features không critical

**Deployment:**
- Max 1-2 deploys/ngày
- Canary: 5% → 25% → 50% → 100% (2 giờ)
- Tiêu chí rollback nghiêm ngặt hơn
- Chỉ deploy trong giờ hành chính

**Monitoring:**
- Review dashboard SLO hàng ngày
- Retrospectives cho mọi outages
- Alerts burn rate: Nhạy hơn


---

### Tier 3: Nguy kịch (25-50% budget còn)
**Trạng thái:** CAM

**Hành động:**
- Freeze features không critical
- Chỉ bug fixes và critical features
- Mọi thay đổi cần SRE approval
- Bắt buộc test staging
- Monitoring sau deploy: 24 giờ

**Deployment:**
- Chỉ emergency changes
- Cần manual approval
- Canary kéo dài: 4+ giờ
- On-call engineer phải có mặt

**Monitoring:**
- Monitoring dashboard real-time
- Auto rollback khi có SLI degradation
- Thông báo executive team

**Kế hoạch recovery:**
- Xác định top reliability issues
- Sprint dedicated cho stability
- Cân nhắc điều chỉnh SLO tạm thời

---

### Tier 4: Cạn kiệt (< 25% hoặc âm)
**Trạng thái:** ĐỎ - KHẨN CẤP

**Hành động:**
- Freeze deployment hoàn toàn
- Chỉ fixes cho P0 incidents
- Thành lập war room
- Toàn bộ team focus reliability
- Báo cáo executive hàng ngày

**Deployment:**
- Thay đổi tối thiểu tuyệt đối
- Cần VP approval
- Bắt buộc có rollback plan
- Rollback tức thì nếu có vấn đề

**Monitoring:**
- War room 24/7
- Theo dõi dashboard liên tục
- Mọi incidents → post-mortem ngay

**Escalation:**
- Thông báo CTO
- Kế hoạch communication khách hàng
- Cập nhật status page external
```



---

## Câu 7: Multi-Window Burn Rate

### a) Tại sao cần 2 windows

**Vấn đề với 1 window:**

Chỉ long window (1h):
```
11:05 - Spike 5% error trong 3 phút
  Window 1h: Vẫn hiện 0.3% (trung bình ra)
  Alert: KHÔNG
  Vấn đề: Bỏ lỡ issue thực sự
```

Chỉ short window (5m):
```
11:05 - Spike ngẫu nhiên 5% trong 10 giây
  Window 5m: Hiện 1% error
  Alert: CÓ
  Vấn đề: False positive, chỉ thoáng qua
```

**Giải pháp: Cần cả 2 windows**

```yaml
expr: |
  burn_rate_1h > threshold    # Vấn đề kéo dài
  and
  burn_rate_5m > threshold    # Vẫn đang xảy ra
```

Lợi ích:
- Long window: Lọc noise, xác nhận kéo dài
- Short window: Xác nhận vẫn active, chưa recover
- Cả 2: Tin cậy cao là issue thật


### b) Tính burn rate

**Tại 11:05 (5% error trong 3 phút):**

Window 5m:
```
Error rate: ~3% (5% trong 3 phút, 0.1% trong 2 phút còn lại)
Burn rate = 3% / 0.1% = 30x
```

Window 1h:
```
Error rate: ~0.15% (5% trong 3 phút, bình thường 57 phút)
Burn rate = 0.15% / 0.1% = 1.5x
```

Trạng thái alert:
```yaml
FastBurn: 
  5m: 30x > 14.4 ✓
  1h: 1.5x < 14.4 ✗
  → KHÔNG ALERT (cần cả 2)

SlowBurn:
  5m: 30x > 6 ✓
  30m: ~5x < 6 ✗
  → KHÔNG ALERT
```

**Tại 11:30 (0.8% error ổn định):**

Window 5m:
```
Error rate: 0.8%
Burn rate = 0.8% / 0.1% = 8x
```

Window 6h:
```
Error rate: ~0.2% (25 phút ở 0.8%, còn lại bình thường)
Burn rate = 0.2% / 0.1% = 2x
```

Window 30m:
```
Error rate: ~0.5% (25 phút ở 0.8%, 5 phút spike)
Burn rate = 0.5% / 0.1% = 5x
```

Trạng thái alert:
```yaml
FastBurn: KHÔNG (cả 2 windows < 14.4)
SlowBurn: KHÔNG (30m window < 6)
```

**Tại 12:00 (0.8% tiếp tục):**
SlowBurn sắp fire khi 6h window bắt kịp


### c) Tại sao FastBurn không fire tại 11:05

Dù error rate 5% (50x burn!), FastBurn cần:
```yaml
burn_rate_1h > 14.4 VÀ burn_rate_5m > 14.4
```

Tại 11:05:
- 5m burn rate: 30x > 14.4 ✓
- 1h burn rate: 1.5x < 14.4 ✗

**Lý do: Window 1h đóng vai trò filter**

3 phút errors không đủ impact window 1 giờ:
```
1 giờ = 60 phút
Error spike = 3 phút = 5% của window
Trung bình: 5% × 0.05 + 0.1% × 0.95 ≈ 0.35%
Burn rate: 0.35% / 0.1% = 3.5x (< 14.4)
```

**Đây là thiết kế có chủ đích:**
- Bảo vệ khỏi spikes thoáng qua
- Yêu cầu error rate kéo dài
- Ngăn false positives

**Trade-off:**
- Phát hiện chậm hơn (cần ~10+ phút errors cao)
- Ít false alarms hơn
- Tỷ lệ signal-to-noise tốt hơn

Nếu spike tiếp tục > 10 phút, window 1h sẽ vượt threshold và alert sẽ fire.

---

## Câu 8: Grafana Dashboard Design

### a) Cấu trúc dashboard cho 3 nhóm stakeholders

**Row 1: Tổng quan điều hành (Management)**
- Uptime tháng này: 99.96%
- SLO status: ✓
- Error budget còn: 68%
- Biểu đồ xu hướng availability hàng tháng


**Row 2: Tuân thủ SLO (Engineers + Management)**
- Availability SLO: Target 99.95%, hiện tại 99.96% ✓
- Latency P95 SLO: Target <500ms, hiện tại 420ms ✓
- Payment Success Rate: Target 99.9%, hiện tại 99.92% ✓
- Mỗi cái có line chart với target line

**Row 3: Metrics vận hành (Engineers + On-call)**
- Request Rate: 1.2k req/s
- Error Rate: 0.04%
- P50 Latency: 180ms
- P99 Latency: 850ms

**Row 4: Error Budget & Burn Rate (Engineers)**
- Error Budget Status: 68% còn, 19.5 ngày với tốc độ hiện tại
- Burn Rate (1h/6h): Hiện tại 0.8x
- Graph multi-window với zones màu

**Row 5: Deep Dive (On-call)**
- Top Errors (1h qua): Table với counts
- Slow Requests (>1s): Table với endpoints

**Row 6: Correlation Links (On-call)**
- Quick links: [Logs] [Traces] [Alerts] [Runbook] [Recent Changes]

### b) Panel Error Budget

**Type:** Gauge + Graph

Gauge thresholds:
- 0-25%: ĐỎ - "CẠN KIỆT - Feature Freeze"
- 25-50%: CAM - "NGUY KỊCH - Chỉ Emergency"
- 50-75%: VÀNG - "THẬN TRỌNG - Chậm lại"
- 75-100%: XANH - "KHỎE MẠNH - Hoạt động bình thường"


Metrics hiển thị:
- Giá trị hiện tại: "68% còn lại"
- Dự đoán thời gian: "19.5 ngày với burn rate hiện tại"
- Phút còn: "29.4 phút / 43.2 tổng"
- Status badge: "KHỎE MẠNH ✓"

Graph bên dưới:
- Trục X: Thời gian (30 ngày)
- Trục Y: Budget % (0-100%)
- Line: Tiêu thụ budget thực tế
- Zones màu matching thresholds
- Annotations: Deployment markers, incidents

### c) Correlation: Metrics → Logs → Traces

**Method 1: Data Links trong Grafana**
```yaml
dataLinks:
  - title: "Xem Logs"
    url: "Link tới Loki với filter status tương ứng"
  - title: "Xem Traces"  
    url: "Link tới Tempo"
```

**Method 2: Trace ID trong Logs**
Query Loki:
```logql
{service="checkout", level="error"}
| json
| trace_id != ""
```
Click trace_id → tự động jump tới Tempo

**Method 3: Exemplars**
Prometheus với exemplars enabled - click metric point → thấy trace liên quan

**Method 4: Unified Explore**
Grafana Explore với split view - đồng bộ time range giữa Metrics/Logs/Traces



---

## Câu 9: OpenTelemetry Sampling

### a) Chiến lược sampling

**Multi-tier sampling:**

**Tier 1: Sample 100%**
- Mọi errors (5xx, 4xx)
- Mọi slow requests (>1s)
- Mọi payment transactions (critical cho business)

**Tier 2: Sample 10%**
- Authentication requests
- Checkout flow
- API endpoints có SLOs

**Tier 3: Sample 1% (baseline)**
- Health checks
- Static content
- Internal endpoints

**Tier 4: Không sample (0%)**
- Kubernetes probes (/health, /ready)
- Metrics scraping endpoints

**Ước tính volume:**
```
Tổng: 10,000 req/s = 864M/ngày

Tier 1 (100%): 30M/ngày
Tier 2 (10%): 17.3M/ngày
Tier 3 (1%): 6M/ngày
Tier 4 (0%): 0

Tổng traces: 53.3M/ngày
Storage: ~53 GB/ngày (vs 864 GB không sampling)
Tiết kiệm: 94%
```

Cân bằng được:
- Giữ tất cả traces quan trọng (errors, slow, business)
- Sample thống kê traffic bình thường
- Giảm chi phí khổng lồ
- Vẫn debug được hầu hết issues


### b) Head sampling vs Tail sampling

**Head Sampling (tại SDK):**

Pros:
- Implementation đơn giản
- Overhead thấp
- Chi phí dự đoán được

Cons:
- Quyết định sớm (chưa biết request sẽ error)
- Có thể drop traces quan trọng (errors, slow)
- All-or-nothing per trace
- Không điều chỉnh based on attributes

Ví dụ vấn đề:
```
Request bắt đầu: Sample? Tung xúc xắc → KHÔNG (dropped)
Request fail 5 giây sau: Quá muộn, đã dropped rồi
Kết quả: Thiếu error trace!
```

**Tail Sampling (tại Collector):**

Pros:
- Quyết định thông minh (sample dựa trên outcome)
- Giữ traces quan trọng (errors, slow)
- Policies linh hoạt
- Chất lượng data tốt hơn

Cons:
- Implementation phức tạp
- Overhead cao hơn (buffer traces)
- Cần centralized collector
- Quyết định trì hoãn (tốn memory)

**Đề xuất: Tail sampling cho production**
Đáng để phức tạp để giữ các traces quan trọng


### c) Config Tail Sampling

```yaml
processors:
  tail_sampling:
    decision_wait: 10s  # Đợi trace hoàn thành
    num_traces: 100000  # Kích thước buffer
    
    policies:
      # Policy 1: Giữ tất cả errors (100%)
      - name: errors-policy
        type: status_code
        status_code:
          status_codes: [ERROR]
      
      # Policy 2: Giữ tất cả slow requests (100%)
      - name: latency-policy
        type: latency
        latency:
          threshold_ms: 1000
      
      # Policy 3: Baseline sampling (1%)
      - name: baseline-policy
        type: probabilistic
        probabilistic:
          sampling_percentage: 1
      
      # Policy 4: Giữ payment transactions (100%)
      - name: payment-policy
        type: string_attribute
        string_attribute:
          key: http.route
          values:
            - /api/payment
            - /api/checkout

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [tail_sampling, batch]
      exporters: [otlp/jaeger]
```

Policies được OR với nhau - match bất kỳ → giữ trace



---

## Câu 10: Incident Response Thực Tế

### a) Quy trình điều tra từng bước

**Bước 1: Xác nhận Alert (30 giây)**

Check Grafana dashboard:
- Alert: ErrorBudgetBurnFast
- Error rate: 1.5% (bình thường 0.05%) → tăng 30x
- Latency: Bình thường (200ms) → không phải vấn đề latency
- Traffic: Bình thường → không phải traffic spike
- Deploy gần đây: Không có → không phải deploy issue

Giả thuyết ban đầu: Vấn đề dependency bên ngoài hoặc data

**Bước 2: Check phân bố Error (1 phút)**

Query Prometheus:
```promql
# Error rate theo endpoint
sum by (endpoint) (
  rate(http_requests_total{service="checkout", status=~"5.."}[5m])
)

# Error rate theo status code
sum by (status) (
  rate(http_requests_total{service="checkout", status=~"5.."}[5m])
)
```

Phát hiện:
```
/api/checkout/payment → 500 errors (1.5%)
/api/checkout/confirm → Bình thường
Status 503: Đa số errors
```

Thu hẹp: Payment endpoint, lỗi service unavailable


**Bước 3: Check Logs (2 phút)**

Query Loki:
```logql
{service="checkout", level="error"}
| json
| endpoint="/api/checkout/payment"
```

Sample logs:
```
02:30:15 Payment gateway timeout: Connection refused
02:30:20 Payment API error: dial tcp 10.0.5.123:443: i/o timeout
02:30:25 Failed to connect to payment-gateway: context deadline exceeded
```

Giả thuyết xác nhận: Vấn đề kết nối payment gateway

**Bước 4: Check Traces (1 phút)**

Query Tempo:
```
service.name="checkout" AND status=error
```

Trace view:
```
POST /api/checkout/payment (5000ms, ERROR)
├─ Validate request (10ms, OK)
├─ Check inventory (50ms, OK)
├─ Call payment-gateway (4950ms, ERROR)
│  └─ HTTP timeout: connection refused
```

Root cause xác nhận: Payment gateway unreachable

**Bước 5: Check Infrastructure (2 phút)**

```bash
kubectl get pods -n payment -l app=payment-gateway

NAME                      READY   STATUS
payment-gateway-abc123    0/1     Running

kubectl logs -n payment payment-gateway-abc123 --tail=50
```

Phát hiện:
```
Connection to database failed: max connections reached
Pool exhausted: 100/100 connections
```

Root cause: Database connection pool của payment gateway hết


**Bước 6: Mitigation ngay lập tức (2 phút)**

Chọn scale up payment gateway (nhiều pods = nhiều connections):
```bash
kubectl scale deployment/payment-gateway --replicas=6 -n payment
```

**Bước 7: Monitor Recovery (3 phút)**

Timeline:
```
02:38 - Scaled to 6 replicas
02:39 - Pods mới healthy
02:40 - Error rate giảm: 1.5% → 0.8%
02:41 - Error rate: 0.3%
02:42 - Error rate: 0.1% (bình thường)
```

Incident resolved: 12 phút tổng

### b) Queries để narrow down root cause

**PromQL:**
```promql
# 1. Overall error rate
sum(rate(http_requests_total{service="checkout", status=~"5.."}[5m]))
/
sum(rate(http_requests_total{service="checkout"}[5m]))

# 2. Error rate theo endpoint
sum by (endpoint) (rate(http_requests_total{service="checkout", status=~"5.."}[5m]))

# 3. Error rate theo status code
sum by (status) (rate(http_requests_total{service="checkout", status=~"5.."}[5m]))

# 4. Dependency health
up{service="payment-gateway"}

# 5. Database connections
db_connections_active{service="payment-gateway"}
```


**LogQL:**
```logql
# 1. Error logs từ checkout service
{service="checkout", level="error"}
| json
| endpoint="/api/checkout/payment"

# 2. Error logs từ payment gateway
{service="payment-gateway", level="error"}

# 3. Correlation với trace ID
{service="checkout", level="error"}
| json
| trace_id != ""
```

**Tempo queries:**
```
service.name="checkout" AND status=error
service.name="payment-gateway" AND status=error
```

### c) Phòng ngừa incidents tương tự

**1. Cải thiện Monitoring:**
- Add metric: `db_connections_active` cho mọi services
- Add metric: `db_connections_max` (pool size)
- Dashboard: Connection pool utilization %
- Alert: Connection pool > 80% utilization

**2. Cải thiện Alerting:**
```yaml
- alert: ConnectionPoolNearlyExhausted
  expr: db_connections_active / db_connections_max > 0.8
  for: 5m
  severity: warning
  annotations:
    summary: "Connection pool gần hết cho {{$labels.service}}"
```

**3. Auto-scaling:**
```yaml
# HPA based on connection pool usage
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: payment-gateway
spec:
  scaleTargetRef:
    name: payment-gateway
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Pods
    pods:
      metric:
        name: db_connections_utilization
      target:
        type: AverageValue
        averageValue: "70"
```


**4. Cải thiện Configuration:**
- Tăng database connection pool size
- Implement connection pooling best practices
- Add connection timeout và retry logic
- Circuit breaker cho payment gateway calls

**5. Load Testing:**
- Test connection pool behavior under load
- Identify thresholds trước khi production
- Simulate failure scenarios

**6. Documentation:**
- Runbook cho connection pool issues
- Post-mortem document
- Share learnings với team

**7. Proactive Capacity Planning:**
- Monitor growth trends
- Plan capacity trước khi đạt limits
- Review connection pool sizes quarterly

**8. Improved Observability:**
- Add tracing cho database connections
- Track connection lifecycle
- Monitor connection wait times
- Alert on connection leaks
