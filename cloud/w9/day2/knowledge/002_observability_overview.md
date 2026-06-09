# Observability Overview

## Observability vs Monitoring

Trước giờ hay nghĩ monitoring và observability là một, nhưng thực ra khác nhau

### Monitoring

Monitoring là:
- Biết trước cần track metrics gì (CPU, memory, request count)
- Dashboard với metrics đã định sẵn
- Alert khi vượt threshold
- Trả lời câu hỏi "Có vấn đề không?"

Ví dụ monitoring:
```
- CPU > 80% → alert
- Memory > 90% → alert
- Request latency > 1s → alert
- Error rate > 5% → alert
```

Vấn đề: Chỉ detect issues đã biết trước

### Observability

Observability là:
- Có thể query bất kỳ câu hỏi nào về system
- Không cần biết trước sẽ có issue gì
- 3 pillars: Metrics, Logs, Traces
- Trả lời câu hỏi "Tại sao có vấn đề?"

Ví dụ observability:
```
Issue: API slow
Questions có thể trả lời:
- Slow ở endpoint nào?
- Database query nào chậm?
- Cache hit rate thế nào?
- Có correlation với deploy không?
- User nào bị ảnh hưởng?
```

System có high observability nghĩa là có thể debug mọi issue dù chưa từng gặp trước đó

## Three Pillars

### 1. Metrics

Numerical measurements over time

Characteristics:
- Aggregatable
- Low storage cost
- Good for trends
- Limited cardinality

Examples:
```
http_requests_total
cpu_usage_percent
memory_bytes
error_count
```

### 2. Logs

Text records of events

Characteristics:
- High cardinality
- Context-rich
- Expensive to store
- Good for debugging

Examples:
```
2024-06-09 10:30:15 INFO User logged in: user_id=123
2024-06-09 10:30:20 ERROR Database connection failed: timeout
```

### 3. Traces

Request journey through distributed system

Characteristics:
- Shows dependencies
- Identifies bottlenecks
- Context propagation
- Performance analysis

Example trace:
```
Request: GET /api/users/123
├─ API Gateway: 5ms
├─ Auth Service: 10ms
├─ User Service: 50ms
│  ├─ Database query: 45ms
│  └─ Cache check: 5ms
└─ Response: 2ms

Total: 67ms
```

## Why Observability Matters

Scenario: API suddenly slow

**With only monitoring:**
```
Alert: API latency p95 > 500ms
```
- Biết có vấn đề
- Không biết nguyên nhân
- Phải guess và test

**With observability:**
```
1. Check metrics: Latency tăng từ 100ms → 600ms
2. Check traces: Database queries chậm
3. Check logs: "Connection pool exhausted"
4. Root cause: Deploy mới tăng concurrency, pool size cũ không đủ
5. Fix: Increase pool size
```

Có observability = faster MTTR (Mean Time To Resolution)

## Signal to Noise Ratio

Challenge: Too much data

Strategy:
- High-value signals
- Aggregate low-value signals
- Sample traces (không cần 100%)
- Structured logging

Example:
```
Bad: Log mọi request
Good: Log errors + sample 1% success requests

Bad: Track mọi metric
Good: Track business metrics + USE metrics

Bad: Trace 100% requests
Good: Trace 1% baseline + 100% errors
```

## Correlation

Power của observability là correlate signals

Example:
```
Deployment at 10:00
↓
Error rate tăng 10:02
↓
Trace shows: New code path
↓
Logs show: Missing config
↓
Root cause: Config không deploy cùng code
```

Tools hỗ trợ correlation:
- Grafana: Annotations cho deploys
- Distributed tracing: Context propagation
- Log correlation IDs
- Unified dashboards

## Observability Best Practices

### 1. Instrumentation from Day 1

Không đợi production mới add monitoring

```javascript
// Bad
function getUser(id) {
  return db.query('SELECT * FROM users WHERE id = ?', [id]);
}

// Good
const getUserDuration = new Histogram({
  name: 'get_user_duration_seconds',
  help: 'Duration of getUser function'
});

async function getUser(id) {
  const end = getUserDuration.startTimer();
  try {
    const user = await db.query('SELECT * FROM users WHERE id = ?', [id]);
    return user;
  } finally {
    end();
  }
}
```

### 2. Structured Logging

```javascript
// Bad
console.log('User ' + userId + ' logged in from ' + ip);

// Good
logger.info('User logged in', {
  user_id: userId,
  ip_address: ip,
  event: 'login',
  timestamp: Date.now()
});
```

Structured logs dễ query và aggregate

### 3. Consistent Naming

```
// Metrics
<namespace>_<subsystem>_<name>_<unit>

http_requests_total
http_request_duration_seconds
database_connections_active

// Logs
{
  "level": "info",
  "service": "api",
  "endpoint": "/users",
  "duration_ms": 150
}

// Traces
Span names: HTTP GET /api/users
Operation names: database.query
```

### 4. Context Propagation

Trace ID đi qua toàn bộ request

```
User request → API Gateway
    trace_id: abc123 ↓
User Service
    trace_id: abc123 ↓
Database
    trace_id: abc123

Logs:
2024-06-09 10:30:15 INFO [trace_id=abc123] User service called
2024-06-09 10:30:16 INFO [trace_id=abc123] Database query executed
```

Dễ dàng trace request qua nhiều services

## Observability Stack

Common components:

Metrics:
- Collection: Prometheus, OpenTelemetry
- Storage: Prometheus, Thanos, Cortex
- Visualization: Grafana

Logs:
- Collection: Fluentd, Promtail
- Storage: Loki, Elasticsearch
- Visualization: Grafana, Kibana

Traces:
- Collection: OpenTelemetry
- Storage: Jaeger, Tempo
- Visualization: Jaeger UI, Grafana

Unified platform:
- Grafana stack: Prometheus + Loki + Tempo
- Datadog, New Relic (commercial)
- OpenTelemetry → multiple backends

## Cardinality

High cardinality = problem

Bad:
```
http_requests_total{user_id="123", path="/users/123"}
http_requests_total{user_id="456", path="/users/456"}
...millions of combinations
```

Good:
```
http_requests_total{method="GET", status="200", endpoint="/users/:id"}
```

Use labels với bounded values:
- method: GET, POST, PUT, DELETE (4 values)
- status: 2xx, 3xx, 4xx, 5xx (4 values)
- endpoint: /users, /posts (10s values)

Avoid labels với unbounded values:
- user_id (millions)
- request_id (unique per request)
- email (unique)

Logs và traces cho high cardinality data
