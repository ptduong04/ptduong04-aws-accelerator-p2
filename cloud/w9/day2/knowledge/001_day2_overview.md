# Day 2 Overview - Observability

## Tổng quan ngày học

Day 2 focus vào Observability - khả năng hiểu được hệ thống đang chạy như thế nào và tại sao có vấn đề.

Theme: Deliver Smartly - Monitor và optimize sau khi deploy

## Nội dung chính

### 1. Observability vs Monitoring

Monitoring:
- Biết CÓ vấn đề
- Dashboard với metrics định sẵn
- Alert khi vượt threshold
- Trả lời: "Có lỗi không?"

Observability:
- Biết TẠI SAO có vấn đề
- Query bất kỳ câu hỏi nào
- Debug issues chưa gặp bao giờ
- Trả lời: "Tại sao lỗi?"

### 2. Three Pillars of Observability

**Metrics** (Chỉ số):
- Numerical data theo thời gian
- Ví dụ: CPU, request count, latency
- Tốt cho trends và alerts
- Chi phí storage thấp

**Logs** (Nhật ký):
- Text records của events
- Context-rich, high cardinality
- Tốt cho debugging chi tiết
- Chi phí storage cao

**Traces** (Dấu vết):
- Request journey qua distributed system
- Thấy dependencies và bottlenecks
- Context propagation
- Performance analysis

### 3. OpenTelemetry (OTel)

Giải quyết:
- Trước đây mỗi tool có format riêng
- OTel = một SDK cho tất cả
- Vendor neutral
- Export ra nhiều backends

Components:
- OTel SDK: Instrumentation trong app
- OTel Collector: Nhận, xử lý, export data
- Multiple backends: Prometheus, Loki, Jaeger, etc.


### 4. Monitoring Stack

**Prometheus:**
- Time-series database cho metrics
- Pull model (scrape targets)
- PromQL query language
- Built-in alerting

**Grafana:**
- Visualization platform
- Multi-datasource support
- Dashboards và alerting
- User management

**Loki:**
- Log aggregation giống Prometheus
- Index labels only (không phải full text)
- Cost-effective
- Tích hợp tốt với Grafana

Flow:
```
Apps → Prometheus (metrics)
     → Loki (logs)
     → Tempo/Jaeger (traces)
       ↓
     Grafana (visualization)
```

### 5. SLO/SLI Methodology

**SLI (Service Level Indicator):**
- Metric đo performance
- Ví dụ: Latency, error rate, availability

**SLO (Service Level Objective):**
- Target cho SLI
- Ví dụ: 99.9% requests < 500ms

**SLA (Service Level Agreement):**
- Contract với customer
- Có consequences nếu vi phạm

**Error Budget:**
- Error budget = 1 - SLO
- Budget còn → ship features
- Budget hết → focus stability

Ví dụ:
```
SLO: 99.9% availability
Error budget: 0.1% = 43 phút/tháng downtime allowed
```


### 6. Multi-Window Burn Rate Alerts

Problem với traditional alerts:
- False positives: Short spikes trigger
- Slow detection: Gradual degradation không catch

Solution: Multi-window burn rate

Burn rate = Tốc độ tiêu thụ error budget

Example:
```
SLO: 99.9% (budget 0.1%)
Error rate 0.5% = 5x burn rate
→ Sẽ hết budget trong 6 ngày
```

Multi-window strategy:
- Long window: Xác nhận sustained problem
- Short window: Xác nhận still happening
- Cả 2: High confidence

Ví dụ alert:
```yaml
alert: FastBurn
expr: |
  burn_rate_1h > 14.4    # Sustained
  and
  burn_rate_5m > 14.4    # Current
for: 2m
```

Tiers:
- 36x burn → Page immediately (hết budget < 1 ngày)
- 10x burn → Page (hết budget < 3 ngày)
- 5x burn → Ticket (hết budget < 6 ngày)
- 2x burn → Monitor (hết budget < 15 ngày)

## Workflow thực tế

1. **Instrumentation:**
   - Add OTel SDK vào apps
   - Auto hoặc manual instrumentation
   - Export tới OTel Collector

2. **Collection:**
   - OTel Collector nhận data
   - Process: Filter, transform, enrich
   - Export tới backends


3. **Storage:**
   - Prometheus: Metrics storage
   - Loki: Log storage
   - Tempo/Jaeger: Trace storage

4. **Visualization:**
   - Grafana dashboards
   - Correlation: Metrics → Logs → Traces
   - Alerting rules

5. **SLO Monitoring:**
   - Define SLIs user-centric
   - Set SLO targets
   - Track error budget
   - Multi-window burn rate alerts

6. **Incident Response:**
   - Alerts fire
   - Check dashboards
   - Correlation để narrow down
   - Fix và monitor recovery

## Key Concepts cần nhớ

**Observability != Monitoring:**
- Monitoring: Known unknowns
- Observability: Unknown unknowns

**Three Pillars cần kết hợp:**
- Metrics: Phát hiện anomaly
- Traces: Xác định bottleneck
- Logs: Giải thích root cause

**OTel = Unified telemetry:**
- Một SDK thay vì nhiều
- Vendor neutral
- Export nhiều backends

**Loki vs Elasticsearch:**
- Loki: Index labels only → rẻ
- ES: Full-text index → đắt nhưng mạnh


**SLI phải user-centric:**
- KHÔNG: CPU, memory
- CÓ: Latency, error rate, availability

**Error Budget làm decision tool:**
- Budget còn nhiều → ship features
- Budget ít → slow down
- Budget hết → freeze

**Burn rate alerts thông minh:**
- Multi-window tránh false positives
- Tiered alerts (36x, 10x, 5x, 2x)
- Actionable timeframes

**Sampling strategy:**
- 100%: Errors, slow, critical transactions
- 10%: Important endpoints
- 1%: Baseline
- 0%: Health checks

## Tools chính

- OpenTelemetry: Instrumentation và collection
- Prometheus: Metrics storage và queries
- Loki: Log aggregation
- Grafana: Visualization tất cả
- Tempo/Jaeger: Distributed tracing

## Best Practices

1. Instrument từ ngày 1
2. Structured logging
3. Consistent naming conventions
4. Context propagation (trace IDs)
5. Low cardinality labels
6. User-centric SLIs
7. Realistic SLO targets
8. Multi-window burn rate alerts
9. Error budget policy rõ ràng
10. Regular SLO reviews

## Khi nào dùng gì

**Dùng Loki khi:**
- Cost-sensitive
- Kubernetes environment
- Đã dùng Grafana
- Query patterns đơn giản

**Dùng Elasticsearch khi:**
- Cần full-text search nhanh
- Complex queries
- Budget không vấn đề

**Head sampling khi:**
- Simple use case
- Predictable cost quan trọng
- Không cần sample intelligent

**Tail sampling khi:**
- Production environment
- Cần giữ important traces
- OK với complexity

## Common Pitfalls

1. Monitoring thay vì observability
2. Quá nhiều metrics (high cardinality)
3. SLIs không user-centric
4. SLO targets unrealistic
5. Không enforce error budget policy
6. Single-window alerts (too many false positives)
7. Không correlate signals
8. Sample tất cả hoặc không sample gì
