# Prometheus + Grafana + Loki Stack

## Architecture Overview

Stack gồm 3 components chính:
- Prometheus: Metrics collection và storage
- Grafana: Visualization và dashboards
- Loki: Log aggregation

```
Applications
  ├─> Prometheus (metrics)
  ├─> Loki (logs)
  └─> Jaeger/Tempo (traces)
        ↓
      Grafana (unified visualization)
```

## Prometheus

### What is Prometheus

Time-series database cho metrics:
- Pull model (scrape targets)
- Powerful query language (PromQL)
- Built-in alerting
- Service discovery

### Data Model

Metric format:
```
metric_name{label1="value1", label2="value2"} value timestamp
```

Example:
```
http_requests_total{method="GET", status="200", path="/api/users"} 1234 1717920000
```

Metric types:
- Counter: Only increase (requests, errors)
- Gauge: Can go up/down (CPU, memory, connections)
- Histogram: Distribution (latency buckets)
- Summary: Similar histogram, client-side quantiles

### Configuration

prometheus.yml:
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        target_label: __address__

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']

rule_files:
  - '/etc/prometheus/rules/*.yml'
```

### PromQL

Basic queries:
```promql
# Current value
http_requests_total

# Filter by labels
http_requests_total{status="200", method="GET"}

# Rate (requests per second)
rate(http_requests_total[5m])

# Sum by label
sum by (status) (rate(http_requests_total[5m]))

# Percentage
sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100
```

Advanced queries:
```promql
# Error rate
sum(rate(http_requests_total{status=~"5.."}[5m])) by (endpoint)

# Latency p95
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Memory usage %
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100

# Predict disk full
predict_linear(node_filesystem_free_bytes[1h], 4 * 3600) < 0
```

### Service Discovery

Kubernetes SD:
```yaml
- job_name: 'kubernetes-pods'
  kubernetes_sd_configs:
    - role: pod
```

Tự động discover pods với annotations:
```yaml
apiVersion: v1
kind: Pod
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"
```

### Recording Rules

Pre-compute expensive queries

```yaml
groups:
  - name: api_metrics
    interval: 30s
    rules:
      - record: api:request_rate:5m
        expr: sum(rate(http_requests_total[5m])) by (endpoint, method)
      
      - record: api:error_rate:5m
        expr: sum(rate(http_requests_total{status=~"5.."}[5m])) by (endpoint) / sum(rate(http_requests_total[5m])) by (endpoint)
      
      - record: api:latency_p95:5m
        expr: histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, endpoint))
```

Use trong queries:
```promql
api:error_rate:5m{endpoint="/api/users"}
```

Faster queries, reduced load

### Alerting Rules

```yaml
groups:
  - name: api_alerts
    rules:
      - alert: HighErrorRate
        expr: api:error_rate:5m > 0.05
        for: 5m
        labels:
          severity: critical
          team: backend
        annotations:
          summary: "High error rate on {{ $labels.endpoint }}"
          description: "Error rate is {{ $value | humanizePercentage }} for 5 minutes"
      
      - alert: HighLatency
        expr: api:latency_p95:5m > 1
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High latency on {{ $labels.endpoint }}"
          description: "P95 latency is {{ $value }}s"
      
      - alert: PodDown
        expr: up{job="kubernetes-pods"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Pod {{ $labels.pod }} is down"
```

## Grafana

### What is Grafana

Visualization platform:
- Multi-datasource support
- Rich dashboards
- Alerting
- User management
- Plugins ecosystem

### Datasources

Add trong Grafana UI hoặc config:
```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    url: http://prometheus:9090
    access: proxy
    isDefault: true
  
  - name: Loki
    type: loki
    url: http://loki:3100
    access: proxy
  
  - name: Tempo
    type: tempo
    url: http://tempo:3200
    access: proxy
```

### Dashboard JSON

```json
{
  "dashboard": {
    "title": "API Metrics",
    "panels": [
      {
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total[5m])) by (endpoint)",
            "legendFormat": "{{ endpoint }}"
          }
        ]
      },
      {
        "title": "Error Rate",
        "type": "stat",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total{status=~\"5..\"}[5m])) / sum(rate(http_requests_total[5m]))"
          }
        ],
        "thresholds": [
          {"value": 0, "color": "green"},
          {"value": 0.01, "color": "yellow"},
          {"value": 0.05, "color": "red"}
        ]
      }
    ]
  }
}
```

### Variables

Dynamic dashboards:
```
Variable name: namespace
Query: label_values(namespace)

Variable name: pod
Query: label_values(kube_pod_info{namespace="$namespace"}, pod)

Use in queries:
http_requests_total{namespace="$namespace", pod=~"$pod"}
```

### Alerting

Grafana alerting (newer than Prometheus alertmanager):
```yaml
apiVersion: 1
groups:
  - name: api-alerts
    interval: 1m
    rules:
      - uid: error-rate-alert
        title: High Error Rate
        condition: B
        data:
          - refId: A
            datasourceUid: prometheus-uid
            model:
              expr: sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))
          - refId: B
            datasourceUid: __expr__
            model:
              type: threshold
              expression: A
              conditions:
                - evaluator:
                    params: [0.05]
                    type: gt
        for: 5m
        annotations:
          description: Error rate is above 5%
        labels:
          severity: critical
```

## Loki

### What is Loki

Log aggregation system:
- Like Prometheus, but for logs
- Index labels, not content
- Cost-effective storage
- LogQL query language

Architecture:
```
Apps → Promtail (agent) → Loki → Grafana
```

### Why Loki

Compare với Elasticsearch:
- Loki: Index labels only → cheaper storage
- ES: Full-text index → expensive, powerful search

Loki best cho:
- Kubernetes logs
- Structured logs
- Correlation với metrics/traces
- Cost-sensitive deployments

### Configuration

loki.yaml:
```yaml
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
  chunk_idle_period: 5m
  chunk_retain_period: 30s

schema_config:
  configs:
    - from: 2024-01-01
      store: boltdb-shipper
      object_store: s3
      schema: v11
      index:
        prefix: loki_index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: /loki/index
    cache_location: /loki/cache
  aws:
    s3: s3://us-west-2/my-loki-bucket

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  ingestion_rate_mb: 10
  ingestion_burst_size_mb: 20
```

### Promtail

Log shipper tương tự như Fluent Bit

promtail.yaml:
```yaml
server:
  http_listen_port: 9080

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: kubernetes-pods
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_label_app]
        target_label: app
      - source_labels: [__meta_kubernetes_pod_name]
        target_label: pod
      - source_labels: [__meta_kubernetes_namespace]
        target_label: namespace
    pipeline_stages:
      - docker: {}
      - json:
          expressions:
            level: level
            message: message
            trace_id: trace_id
      - labels:
          level:
          trace_id:
```

### LogQL

Basic queries:
```logql
# All logs from app
{app="myapp"}

# Filter by log level
{app="myapp"} |= "error"

# Regex filter
{app="myapp"} |~ "error|exception"

# JSON parsing
{app="myapp"} | json | level="error"

# Line format
{app="myapp"} | line_format "{{.timestamp}} {{.message}}"
```

Aggregations:
```logql
# Count logs
count_over_time({app="myapp"}[5m])

# Rate (logs per second)
rate({app="myapp"}[5m])

# Count by level
sum by (level) (count_over_time({app="myapp"}[5m]))

# Error rate
sum(rate({app="myapp", level="error"}[5m])) / sum(rate({app="myapp"}[5m]))
```

Advanced:
```logql
# Extract latency from logs
{app="myapp"} 
  | json 
  | duration > 1s 
  | line_format "Slow request: {{.path}} took {{.duration}}"

# Pattern matching
{app="myapp"} 
  | pattern `<timestamp> <level> <message>`
  | level = "error"
```

### Correlation

Logs → Traces correlation:
```logql
{app="myapp"} | json | trace_id="abc123"
```

Click trace_id trong Grafana → jump to Jaeger/Tempo

Metrics → Logs correlation:
```promql
# In Grafana, link from panel
http_requests_total{status="500"}
```
Click → filter logs:
```logql
{app="myapp", status="500"}
```

## Complete Stack Deployment

Kubernetes deployment:

```yaml
# Prometheus
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
data:
  prometheus.yml: |
    # ... prometheus config
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        volumeMounts:
        - name: config
          mountPath: /etc/prometheus
        - name: storage
          mountPath: /prometheus
      volumes:
      - name: config
        configMap:
          name: prometheus-config
      - name: storage
        persistentVolumeClaim:
          claimName: prometheus-storage
---
# Loki
apiVersion: apps/v1
kind: Deployment
metadata:
  name: loki
spec:
  template:
    spec:
      containers:
      - name: loki
        image: grafana/loki:latest
        volumeMounts:
        - name: config
          mountPath: /etc/loki
        - name: storage
          mountPath: /loki
---
# Promtail DaemonSet
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
        - name: config
          mountPath: /etc/promtail
        - name: varlog
          mountPath: /var/log
        - name: varlibdocker
          mountPath: /var/lib/docker/containers
          readOnly: true
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdocker
        hostPath:
          path: /var/lib/docker/containers
---
# Grafana
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
spec:
  template:
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:latest
        env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: grafana-secret
              key: admin-password
        volumeMounts:
        - name: datasources
          mountPath: /etc/grafana/provisioning/datasources
        - name: dashboards
          mountPath: /etc/grafana/provisioning/dashboards
      volumes:
      - name: datasources
        configMap:
          name: grafana-datasources
      - name: dashboards
        configMap:
          name: grafana-dashboards
```

## Best Practices

### Prometheus

1. Use recording rules cho expensive queries
2. Monitor Prometheus itself
3. Configure retention (default 15d)
4. Use remote storage cho long-term
5. Avoid high cardinality labels

### Grafana

1. Use variables cho reusable dashboards
2. Template dashboards cho teams
3. Setup alerting channels (Slack, PagerDuty)
4. Version control dashboards (JSON)
5. Use folders organize dashboards

### Loki

1. Structure logs (JSON)
2. Use limited labels (high cardinality = problem)
3. Include trace IDs cho correlation
4. Configure retention policy
5. Use S3/GCS cho storage

## Troubleshooting

### Prometheus not scraping

Check:
```bash
# Prometheus targets
curl localhost:9090/targets

# Metrics endpoint accessible?
curl pod-ip:8080/metrics

# Service discovery working?
curl localhost:9090/api/v1/targets
```

### Loki not receiving logs

Check:
```bash
# Promtail logs
kubectl logs -n monitoring promtail-xxxx

# Loki ready endpoint
curl localhost:3100/ready

# Query logs
curl -G 'http://localhost:3100/loki/api/v1/query' --data-urlencode 'query={app="myapp"}'
```

### Grafana datasource issues

Check:
```bash
# Test datasource
curl -H "Authorization: Bearer <api-key>" \
  http://grafana:3000/api/datasources/proxy/1/api/v1/query?query=up

# Check datasource config
kubectl get cm grafana-datasources -o yaml
```
