# Day 2 Observability Assessment

## Question 1: Observability vs Monitoring

API của bạn đột ngột chậm, response time tăng từ 100ms lên 2 seconds.

**Scenario A - Monitoring only:**
- Dashboard hiện CPU 45%, Memory 60%, Disk 30%
- Alert: "API latency > 1s"
- Không có thêm context

**Scenario B - Full Observability:**
- Metrics: Latency p95 = 2.1s, started 10:30 AM
- Traces: Database query "SELECT * FROM orders WHERE..." takes 1.9s
- Logs: "Connection pool exhausted: 100/100 connections in use"

a) Giải thích sự khác biệt giữa monitoring và observability dựa vào 2 scenarios trên

b) Trong Scenario B, 3 pillars nào được sử dụng và mỗi pillar cung cấp thông tin gì?

c) Tại sao monitoring không đủ để debug issue này?

---

## Question 2: OpenTelemetry Architecture

Công ty có microservices architecture: API Gateway → User Service → Database

**Current situation:**
- API Gateway: Instrumented với Jaeger SDK
- User Service: Instrumented với Zipkin SDK  
- Database: Prometheus metrics only

Team muốn:
- Unified telemetry system
- Export tới multiple backends (Prometheus + Loki + Jaeger)
- Minimal code changes

a) Đề xuất architecture sử dụng OpenTelemetry, giải thích các components

b) OTel Collector nên deploy theo pattern nào (agent/gateway/hybrid) và tại sao?

c) Viết PromQL query để track burn rate cho availability SLO 99.9% với 5-minute window

---

## Question 3: Prometheus Query

Service có metrics:
```
http_requests_total{method="GET", path="/api/users", status="200"} 45000
http_requests_total{method="GET", path="/api/users", status="500"} 500
http_requests_total{method="POST", path="/api/users", status="201"} 5000
http_requests_total{method="POST", path="/api/users", status="500"} 100

http_request_duration_seconds_bucket{path="/api/users", le="0.1"} 30000
http_request_duration_seconds_bucket{path="/api/users", le="0.5"} 48000
http_request_duration_seconds_bucket{path="/api/users", le="1.0"} 50000
http_request_duration_seconds_bucket{path="/api/users", le="+Inf"} 50600
```

a) Viết PromQL tính error rate (4xx + 5xx) cho endpoint `/api/users` trong 5 phút qua

b) Viết PromQL tính p95 latency cho endpoint này

c) Giải thích tại sao cần dùng `rate()` function thay vì chỉ sum counter values

---

## Question 4: Loki vs Elasticsearch

Team đang consider giữa Loki và Elasticsearch cho log aggregation.

**Requirements:**
- 50 microservices, mỗi service 10k logs/second
- Cần search logs by trace_id, user_id, error messages
- Budget limited, storage cost là concern
- Đã dùng Grafana cho metrics visualization
- Kubernetes environment

a) So sánh Loki và Elasticsearch về indexing strategy

b) Recommend solution cho requirements trên, giải thích lý do

c) Với Loki, labels nào nên index và data nào nên để trong log content? Tại sao?

---

## Question 5: SLI Selection

E-commerce platform có user journey:
```
1. User search products (Search API)
2. Click product detail (Product API)
3. Add to cart (Cart API)
4. Checkout (Payment API)
5. Receive confirmation email (Email Service)
```

**Current metrics tracked:**
- CPU, Memory, Disk usage
- Request count per endpoint
- Database query time
- Cache hit ratio

a) Đề xuất SLIs user-centric cho platform này (ít nhất 3 SLIs)

b) Vì sao không nên dùng CPU/Memory làm SLI chính?

c) Payment API critical hơn Search API. SLO targets nên khác nhau như thế nào?

---

## Question 6: Error Budget Policy

Service có SLO: 99.9% availability trong 30 days

**Current month status:**
- Day 1-10: 99.95% availability
- Day 11-15: Incident, availability dropped to 99.5%
- Day 16-20: Recovered to 99.92%
- Day 21 (today): 99.85% availability for the month

a) Tính error budget còn lại (% và minutes)

b) Theo error budget consumed, team nên làm gì? (feature work, freeze, etc.)

c) Thiết kế error budget policy với 3-4 thresholds và corresponding actions

---

## Question 7: Multi-Window Burn Rate

Service có SLO 99.9% availability (error budget 0.1%)

**Alert configuration:**
```yaml
- alert: FastBurn
  expr: |
    burn_rate_1h > 14.4
    and
    burn_rate_5m > 14.4
  for: 2m

- alert: SlowBurn
  expr: |
    burn_rate_6h > 6
    and
    burn_rate_30m > 6
  for: 15m
```

**Incident timeline:**
11:00 - Deploy new version
11:05 - Error rate spikes to 5% for 3 minutes, then drops to 0.2%
11:30 - Error rate steady at 0.8%
12:00 - Error rate still at 0.8%

a) Tại sao cần 2 windows (long + short) thay vì chỉ 1 window?

b) Calculate burn rate tại 11:05 và 11:30. Alert nào sẽ fire và tại thời điểm nào?

c) Giải thích tại sao FastBurn alert không fire tại 11:05 despite high error rate

---

## Question 8: Grafana Dashboard Design

Team cần dashboard monitor checkout service với:

**SLOs:**
- Availability: 99.95%
- Latency p95: < 500ms
- Payment success rate: > 99.9%

**Stakeholders:**
- Engineers: Need detailed metrics, burn rates, traces correlation
- Management: Need uptime %, SLO compliance, error budget status
- On-call: Need quick diagnosis, actionable alerts

a) Thiết kế dashboard structure với panels cho 3 stakeholder groups

b) Với panel "Error Budget", cần hiển thị metrics nào và threshold colors nào?

c) Làm sao correlate metrics → logs → traces trong Grafana?

---

## Question 9: OpenTelemetry Sampling

Production service nhận 10,000 requests/second

**No sampling:**
- 10k traces/sec = 864 million traces/day
- Storage: ~1KB per trace = 864 GB/day
- Cost: High

**Current strategy:**
- Sample all traces: Too expensive
- Don't sample: Can't debug issues

a) Đề xuất sampling strategy cân bằng cost và observability

b) So sánh head sampling (at SDK) vs tail sampling (at Collector)

c) Implement tail sampling config: 100% errors, 100% slow requests (>1s), 1% baseline

---

## Question 10: Real-World Incident Response

**Incident:**
- Time: 2:30 AM
- Alert: "ErrorBudgetBurnFast: Checkout service burning error budget at 15x rate"
- On-call engineer wakes up

**Available tools:**
- Grafana dashboards
- Prometheus + Loki + Tempo
- Kubernetes cluster access
- Git history

**Initial observations:**
- Error rate: 1.5% (normal: 0.05%)
- Latency p95: Normal (200ms)
- No recent deploys
- CPU/Memory: Normal

a) Step-by-step investigation process using observability tools

b) Queries (PromQL/LogQL) để narrow down root cause

c) Sau khi fix, làm sao prevent similar incident? (monitoring improvements, alerting, etc.)
