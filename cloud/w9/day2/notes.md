# Day 2 - Observability và Monitoring

Hôm nay học về observability, concept khá rộng và có nhiều tool phải setup

## Observability vs Monitoring

Trước giờ hay nghĩ monitoring và observability là một, nhưng thực ra khác nhau:

Monitoring:
- Biết trước cần track metrics gì (CPU, memory, request count)
- Dashboard với metrics đã định sẵn
- Alert khi vượt threshold
- Trả lời câu hỏi "Có vấn đề không?"

Observability:
- Có thể query bất kỳ câu hỏi nào về system
- Không cần biết trước sẽ có issue gì
- 3 pillars: Metrics, Logs, Traces
- Trả lời câu hỏi "Tại sao có vấn đề?"

System có high observability nghĩa là có thể debug mọi issue dù chưa từng gặp trước đó

## SLI, SLO, SLA

Đây là foundation của SRE, Google viết nhiều về chủ đề này

### SLI - Service Level Indicator

Metric đo lường service health. Thường là tỉ lệ phần trăm.

Ví dụ:
- Availability: 99.5% requests trả về 200 OK
- Latency: 95% requests dưới 200ms
- Error rate: 0.1% requests bị lỗi

SLI phải:
- Measurable (đo được)
- Meaningful (có ý nghĩa với user)
- Actionable (có thể improve)

### SLO - Service Level Objective

Target cho SLI. Đây là goal cần đạt.

Ví dụ:
- SLO availability: 99.9% uptime
- SLO latency: p95 < 200ms
- SLO error rate: < 0.5%

Không nên đặt SLO 100% vì:
- Unrealistic, tốn nhiều resource
- Không có error budget để deploy
- User không cảm nhận được khác biệt giữa 99.9% và 100%

### SLA - Service Level Agreement

Contract với customer, có penalty nếu vi phạm.

SLA thường loose hơn SLO để có buffer. Ví dụ:
- SLO internal: 99.9%
- SLA với customer: 99.5%

Buffer này cho phép có incident nhỏ mà không vi phạm SLA

## Error Budget

Concept hay từ Google SRE. Nếu SLO là 99.9%, nghĩa là có 0.1% error budget.

Error budget cho phép:
- Deploy features mới (có risk)
- Experiment
- Planned downtime

Khi hết error budget:
- Freeze features
- Focus stability
- Fix bugs, improve reliability

Đây là cách balance giữa velocity và reliability

## OpenTelemetry (OTel)

OTel là standard mới cho observability, thay thế các format riêng lẻ trước đây

### Why OTel

Trước OTel:
- Prometheus có format riêng
- Jaeger có format riêng
- App phải instrument với nhiều SDK khác nhau
- Vendor lock-in

Với OTel:
- Một SDK cho tất cả (metrics, logs, traces)
- Export sang nhiều backend (Prometheus, Jaeger, Datadog...)
- Vendor neutral
- CNCF project, được nhiều công ty support

### OTel Architecture

```
Application
  |
  +-- OTel SDK (instrument code)
  |
  v
OTel Collector (agent)
  |
  +-- Process, filter, enrich data
  |
  v
Multiple backends
  +-- Prometheus (metrics)
  +-- Loki (logs)
  +-- Jaeger (traces)
```

### Instrumenting Application

Ví dụ với Node.js:

```javascript
const opentelemetry = require('@opentelemetry/api');
const { NodeTracerProvider } = require('@opentelemetry/sdk-trace-node');
const { PrometheusExporter } = require('@opentelemetry/exporter-prometheus');

// Setup tracer
const provider = new NodeTracerProvider();
provider.register();

// Setup metrics
const exporter = new PrometheusExporter({ port: 9464 });

// Instrument HTTP calls
const tracer = opentelemetry.trace.getTracer('my-service');

app.get('/api/users', async (req, res) => {
  const span = tracer.startSpan('get_users');
  
  try {
    const users = await db.query('SELECT * FROM users');
    span.setStatus({ code: opentelemetry.SpanStatusCode.OK });
    res.json(users);
  } catch (error) {
    span.setStatus({ 
      code: opentelemetry.SpanStatusCode.ERROR,
      message: error.message 
    });
    res.status(500).json({ error: error.message });
  } finally {
    span.end();
  }
});
```

Auto-instrumentation cũng available cho nhiều framework, không cần code thủ công

### OTel Collector Config

```yaml
receivers:
  otlp:
    protocols:
      grpc:
      http:

processors:
  batch:
    timeout: 10s
    send_batch_size: 1024
  
  attributes:
    actions:
      - key: environment
        value: production
        action: insert

exporters:
  prometheus:
    endpoint: "0.0.0.0:8889"
  
  logging:
    loglevel: debug

service:
  pipelines:
    metrics:
      receivers: [otlp]
      processors: [batch, attributes]
      exporters: [prometheus, logging]
```

Collector giúp decouple app và backend, có thể thay đổi backend mà không cần redeploy app

## Prometheus

Prometheus là de-facto standard cho metrics trong K8s

### Architecture

```
Prometheus Server
  |
  +-- Scrape metrics từ targets (pull model)
  +-- Store trong TSDB (time series database)
  +-- Evaluate alerting rules
  +-- Serve queries (PromQL)
```

### Metrics Types

1. Counter: Chỉ tăng, reset khi restart
   - http_requests_total
   - errors_total

2. Gauge: Có thể tăng giảm
   - cpu_usage
   - memory_usage
   - active_connections

3. Histogram: Phân bố values
   - request_duration_seconds
   - Tự động tạo _sum, _count, _bucket

4. Summary: Tương tự histogram nhưng tính percentiles ở client
   - Ít dùng, histogram preferred

### Service Discovery

Prometheus tự động discover targets trong K8s:

```yaml
scrape_configs:
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        target_label: __address__
        regex: (.+)
        replacement: $1:__meta_kubernetes_pod_annotation_prometheus_io_port
```

Pod cần có annotations:
```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/metrics"
```

### PromQL Examples

Học được một số queries hữu ích:

Request rate (QPS):
```
rate(http_requests_total[5m])
```

Error rate:
```
rate(http_requests_total{status=~"5.."}[5m]) 
  / 
rate(http_requests_total[5m])
```

P95 latency:
```
histogram_quantile(0.95, 
  rate(http_request_duration_seconds_bucket[5m])
)
```

CPU usage per pod:
```
sum(rate(container_cpu_usage_seconds_total[5m])) by (pod)
```

## Grafana

Grafana để visualize metrics từ Prometheus

### Dashboard Design

Best practices học được:

1. Tổ chức theo USE method (Utilization, Saturation, Errors):
   - Row 1: Request rate, error rate
   - Row 2: Latency (p50, p95, p99)
   - Row 3: Resource usage (CPU, memory)

2. Variables cho flexibility:
   ```
   $namespace
   $pod
   $interval
   ```

3. Thresholds và colors:
   - Green: Good
   - Yellow: Warning (approaching SLO)
   - Red: Critical (violating SLO)

4. Annotations cho deployments:
   - Show khi nào deploy
   - Correlate issues với changes

### Panel Types

Time series: Cho metrics theo thời gian
Gauge: Cho current value với threshold
Table: Cho list of values
Stat: Cho single value (uptime, current QPS)
Heatmap: Cho latency distribution

## Loki

Loki giống như "Prometheus cho logs". Design để work tốt với Kubernetes.

### Architecture

Không index log content (khác ELK), chỉ index labels. Điều này làm Loki:
- Cost-effective hơn
- Query chậm hơn nếu không dùng labels đúng
- Phù hợp với cloud-native apps

### LogQL

Query language tương tự PromQL

Get logs:
```
{namespace="production", app="api"}
```

Filter by content:
```
{app="api"} |= "error"
```

Regex filter:
```
{app="api"} |~ "error|exception"
```

Metrics from logs:
```
rate({app="api"} |= "error" [5m])
```

Có thể derive metrics từ logs, nhưng structured logging (metrics) vẫn preferred

### Promtail

Promtail là agent ship logs tới Loki, chạy như DaemonSet trên mỗi node

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: promtail
spec:
  template:
    spec:
      containers:
      - name: promtail
        image: grafana/promtail:latest
        volumeMounts:
        - name: pods
          mountPath: /var/log/pods
          readOnly: true
        - name: config
          mountPath: /etc/promtail
      volumes:
      - name: pods
        hostPath:
          path: /var/log/pods
```

## Multi-Window Burn Rate Alerts

Đây là phần khó nhất hôm nay, Google SRE book có viết chi tiết

### Problem với Simple Threshold

Alert đơn giản:
```
rate(http_errors[5m]) / rate(http_requests[5m]) > 0.01
```

Issues:
- False positive nếu có spike ngắn
- Alert chậm nếu error rate tăng dần
- Không liên quan đến error budget

### Burn Rate

Burn rate đo tốc độ tiêu error budget

SLO: 99.9% (error budget 0.1% trong 30 days)

Burn rate 1: Hết budget sau đúng 30 days
Burn rate 2: Hết budget sau 15 days (faster)
Burn rate 10: Hết budget sau 3 days (critical)

Formula:
```
burn_rate = (observed_error_rate / allowed_error_rate)
```

### Multi-Window

Dùng 2 windows: short và long

Fast burn (1 hour / 5 minutes):
```yaml
- alert: ErrorBudgetBurnFast
  expr: |
    (
      rate(http_errors[1h]) / rate(http_requests[1h]) > 0.01 * 14.4
    )
    and
    (
      rate(http_errors[5m]) / rate(http_requests[5m]) > 0.01 * 14.4
    )
  for: 2m
  annotations:
    summary: Fast burn rate detected
```

Slow burn (6 hours / 30 minutes):
```yaml
- alert: ErrorBudgetBurnSlow
  expr: |
    (
      rate(http_errors[6h]) / rate(http_requests[6h]) > 0.01 * 6
    )
    and
    (
      rate(http_errors[30m]) / rate(http_requests[30m]) > 0.01 * 6
    )
  for: 15m
  annotations:
    summary: Slow burn rate detected
```

Long window detect trend, short window confirm hiện tại vẫn bad

Burn rate thresholds:
- 14.4 cho fast: Hết budget trong 2 days
- 6 cho slow: Hết budget trong 5 days

## Setup Local Observability Stack

Hôm nay đã setup stack hoàn chỉnh với Helm

```bash
# Add repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Prometheus
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace

# Install Loki
helm install loki grafana/loki-stack \
  --namespace monitoring

# Install OpenTelemetry Collector
helm install otel-collector open-telemetry/opentelemetry-collector \
  --namespace monitoring
```

Access Grafana:
```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Default: admin / prom-operator
```

## Availability vs Latency SLO

Hôm nay cũng học được cách define 2 loại SLO chính

### Availability SLO

Based on success rate:
```
availability = successful_requests / total_requests

SLI query:
sum(rate(http_requests_total{status!~"5.."}[30d]))
  /
sum(rate(http_requests_total[30d]))

Target: >= 0.999 (99.9%)
```

### Latency SLO

Based on percentile:
```
latency_slo = requests_under_threshold / total_requests

SLI query:
histogram_quantile(0.95, 
  rate(http_request_duration_seconds_bucket[30d])
) < 0.2

Target: p95 < 200ms
```

Thường track cả availability và latency, vì service có thể slow nhưng không fail

## Challenges gặp hôm nay

1. Prometheus OOMKilled
   - Do scrape interval quá ngắn và quá nhiều targets
   - Fix: Tăng memory limit và adjust scrape_interval

2. Grafana dashboard không show data
   - Data source chưa config đúng
   - Fix: Update Prometheus URL trong data source settings

3. Loki query timeout
   - Query không có labels, scan toàn bộ logs
   - Fix: Thêm labels vào query

4. OTel collector không nhận metrics
   - Network policy block traffic
   - Fix: Allow port 4317 (gRPC) trong policy

## Key Takeaways

- Observability không phải chỉ về tools mà về ability to understand system
- SLO phải realistic và aligned với user experience
- Error budget là tool để balance velocity vs stability
- Multi-window burn rate alerts reduce false positives
- Labels trong Prometheus/Loki rất quan trọng cho query performance

