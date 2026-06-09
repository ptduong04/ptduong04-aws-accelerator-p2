# OpenTelemetry SDK và Collector

## Why OpenTelemetry

Trước OTel, mỗi tool có format riêng:
- Prometheus: Prometheus format
- Jaeger: Jaeger format
- Zipkin: Zipkin format

App phải instrument với nhiều SDK khác nhau, vendor lock-in nghiêm trọng.

OTel giải quyết:
- Một SDK cho tất cả (metrics, logs, traces)
- Export sang nhiều backend
- Vendor neutral
- CNCF graduated project

## Architecture

```
Application
  |
  +-- OTel SDK (auto/manual instrumentation)
  |
  v
OTel Collector (optional agent)
  |
  +-- Receive, process, export data
  |
  v
Multiple backends
  +-- Prometheus (metrics)
  +-- Loki (logs)
  +-- Jaeger (traces)
  +-- Datadog, New Relic, etc.
```

## OTel SDK

### Auto-instrumentation

Cho popular frameworks, không cần code thay đổi

Node.js example:
```javascript
// tracing.js
const { NodeTracerProvider } = require('@opentelemetry/sdk-trace-node');
const { registerInstrumentations } = require('@opentelemetry/instrumentation');
const { HttpInstrumentation } = require('@opentelemetry/instrumentation-http');
const { ExpressInstrumentation } = require('@opentelemetry/instrumentation-express');

const provider = new NodeTracerProvider();
provider.register();

registerInstrumentations({
  instrumentations: [
    new HttpInstrumentation(),
    new ExpressInstrumentation(),
  ],
});
```

App code:
```javascript
require('./tracing');  // Import ở đầu
const express = require('express');
const app = express();

// Không cần thay đổi code
app.get('/users', async (req, res) => {
  const users = await db.query('SELECT * FROM users');
  res.json(users);
});
```

Auto-instrumentation tự động:
- Tạo spans cho HTTP requests
- Propagate context
- Extract headers
- Add attributes

### Manual instrumentation

Khi cần custom spans

```javascript
const opentelemetry = require('@opentelemetry/api');
const tracer = opentelemetry.trace.getTracer('my-service');

app.get('/api/users', async (req, res) => {
  const span = tracer.startSpan('get_users');
  
  try {
    // Add attributes
    span.setAttribute('user_id', req.user.id);
    span.setAttribute('environment', 'production');
    
    // Child span
    const dbSpan = tracer.startSpan('database.query', {
      parent: span
    });
    const users = await db.query('SELECT * FROM users');
    dbSpan.end();
    
    span.setStatus({ code: opentelemetry.SpanStatusCode.OK });
    res.json(users);
  } catch (error) {
    span.recordException(error);
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

### Metrics SDK

```javascript
const { MeterProvider } = require('@opentelemetry/sdk-metrics');
const { PrometheusExporter } = require('@opentelemetry/exporter-prometheus');

const exporter = new PrometheusExporter({ port: 9464 });
const meterProvider = new MeterProvider();
meterProvider.addMetricReader(exporter);

const meter = meterProvider.getMeter('my-service');

// Counter
const requestCounter = meter.createCounter('http_requests_total', {
  description: 'Total HTTP requests'
});

// Histogram
const requestDuration = meter.createHistogram('http_request_duration_seconds', {
  description: 'HTTP request duration'
});

app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    
    requestCounter.add(1, {
      method: req.method,
      status: res.statusCode,
      route: req.route?.path || 'unknown'
    });
    
    requestDuration.record(duration, {
      method: req.method,
      status: res.statusCode
    });
  });
  
  next();
});
```

## OTel Collector

Collector là agent nhận, process, và export telemetry data

### Why Collector

Benefits:
- Decouple app và backend
- Process data (filter, transform, aggregate)
- Multiple exporters (fan-out)
- Buffer và retry
- Offload processing từ app

Architecture:
```
Multiple apps → Collector → Multiple backends
```

### Deployment Patterns

**Agent pattern:**
- Collector chạy trên mỗi node (DaemonSet)
- Apps send tới local collector
- Low latency, high availability

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
        ports:
        - containerPort: 4317  # OTLP gRPC
        - containerPort: 4318  # OTLP HTTP
```

**Gateway pattern:**
- Collector chạy như Deployment
- Centralized processing
- Scaling độc lập

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-gateway
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: otel-collector
        image: otel/opentelemetry-collector:latest
```

**Hybrid:**
- Agent collectors trên nodes
- Forward tới gateway
- Agent: Minimal processing
- Gateway: Heavy processing

### Configuration

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
  
  prometheus:
    config:
      scrape_configs:
        - job_name: 'otel-collector'
          scrape_interval: 10s
          static_configs:
            - targets: ['localhost:8888']

processors:
  batch:
    timeout: 10s
    send_batch_size: 1024
  
  attributes:
    actions:
      - key: environment
        value: production
        action: insert
      - key: cluster
        value: us-west-2
        action: insert
  
  resource:
    attributes:
      - key: service.version
        from_attribute: app.version
        action: upsert
  
  filter:
    metrics:
      exclude:
        match_type: regexp
        metric_names:
          - .*test.*

exporters:
  prometheus:
    endpoint: "0.0.0.0:8889"
    namespace: "otel"
  
  otlp/jaeger:
    endpoint: jaeger:4317
    tls:
      insecure: true
  
  loki:
    endpoint: http://loki:3100/loki/api/v1/push
  
  logging:
    loglevel: debug

service:
  pipelines:
    metrics:
      receivers: [otlp, prometheus]
      processors: [batch, attributes, filter]
      exporters: [prometheus, logging]
    
    traces:
      receivers: [otlp]
      processors: [batch, attributes]
      exporters: [otlp/jaeger, logging]
    
    logs:
      receivers: [otlp]
      processors: [batch, attributes]
      exporters: [loki, logging]
```

### Processors

**Batch processor:**
- Buffer data trước khi export
- Reduce network calls
- Improve throughput

**Attributes processor:**
- Add, update, delete attributes
- Enrich data với context

**Filter processor:**
- Drop unwanted data
- Reduce storage cost
- Remove sensitive info

**Transform processor:**
- Modify metric names
- Aggregate metrics
- Complex transformations

Example transform:
```yaml
processors:
  transform:
    metric_statements:
      - context: metric
        statements:
          - set(description, "new description")
          - set(unit, "ms")
      - context: datapoint
        statements:
          - set(attributes["new_attr"], "value")
```

## Integration với App

### Environment variables

```bash
# Exporter
export OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317

# Service info
export OTEL_SERVICE_NAME=my-service
export OTEL_SERVICE_VERSION=1.2.3

# Resource attributes
export OTEL_RESOURCE_ATTRIBUTES=environment=production,region=us-west-2

# Sampling
export OTEL_TRACES_SAMPLER=parentbased_traceidratio
export OTEL_TRACES_SAMPLER_ARG=0.1  # 10% sampling
```

### Kubernetes deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    spec:
      containers:
      - name: app
        image: myapp:latest
        env:
        - name: OTEL_EXPORTER_OTLP_ENDPOINT
          value: "http://otel-agent:4317"
        - name: OTEL_SERVICE_NAME
          value: "myapp"
        - name: OTEL_RESOURCE_ATTRIBUTES
          value: "environment=production,pod=$(POD_NAME)"
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
```

## Sampling

Không cần trace 100% requests

### Head sampling (at SDK)

Quyết định sample ngay khi tạo span

```javascript
const { TraceIdRatioBasedSampler } = require('@opentelemetry/sdk-trace-base');

const provider = new NodeTracerProvider({
  sampler: new TraceIdRatioBasedSampler(0.1)  // 10%
});
```

### Tail sampling (at Collector)

Quyết định sau khi trace complete, based on attributes

```yaml
processors:
  tail_sampling:
    policies:
      - name: sample-errors
        type: status_code
        status_code:
          status_codes: [ERROR]
      
      - name: sample-slow
        type: latency
        latency:
          threshold_ms: 1000
      
      - name: sample-baseline
        type: probabilistic
        probabilistic:
          sampling_percentage: 1
```

Strategy:
- Always sample errors và slow requests
- 1% baseline sampling cho normal requests
- Reduced cost nhưng có data khi cần

## Best Practices

1. Start với auto-instrumentation
   - Less code changes
   - Quick wins
   - Add manual instrumentation sau

2. Use Collector
   - Decouple app và backend
   - Flexibility switch backends
   - Centralized processing

3. Sampling strategy
   - Head sampling: Simple, predictable cost
   - Tail sampling: Smarter, keep important traces

4. Resource attributes
   - Add service info, version, environment
   - Easy filtering và grouping

5. Semantic conventions
   - Follow OTel specs
   - Consistent naming
   - Better tool support
