# AnalysisTemplate with Prometheus

## Overview

AnalysisTemplate defines how to query metrics and determine success/failure of a canary deployment. Prometheus is the most common metrics provider for Argo Rollouts.

## Basic AnalysisTemplate Structure

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: basic-check
spec:
  metrics:
  - name: metric-name
    interval: 5m              # How often to query
    count: 5                  # How many times to query
    successCondition: result < threshold
    failureCondition: result >= threshold
    provider:
      prometheus:
        address: http://prometheus.monitoring:9090
        query: |
          your_prometheus_query_here
```

## Prometheus Integration Setup

### 1. Configure Prometheus Access

**In-cluster Prometheus:**
```yaml
provider:
  prometheus:
    address: http://prometheus-server.monitoring.svc.cluster.local:9090
```

**External Prometheus with authentication:**
```yaml
provider:
  prometheus:
    address: https://prometheus.example.com
    authentication:
      oauth2:
        tokenUrl: https://auth.example.com/token
        clientId: my-client-id
        clientSecret: my-secret
        scopes:
        - prometheus.read
```

**Using Secret for credentials:**
```yaml
provider:
  prometheus:
    address: https://prometheus.example.com
    authentication:
      sigv4:
        region: us-west-2
        profile: production
```

### 2. ServiceAccount Permissions

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: argo-rollouts
  namespace: argo-rollouts
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: argo-rollouts-metric-reader
rules:
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get", "list"]
- nonResourceURLs: ["/api/v1/query", "/api/v1/query_range"]
  verbs: ["get"]
```

## Common Prometheus Queries

### 1. Error Rate

**HTTP 5xx error rate:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: error-rate
spec:
  args:
  - name: service-name
  metrics:
  - name: error-rate
    interval: 2m
    successCondition: result < 0.05  # Less than 5% error rate
    failureLimit: 3
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          sum(rate(
            http_requests_total{
              job="{{args.service-name}}",
              status=~"5.."
            }[5m]
          )) 
          /
          sum(rate(
            http_requests_total{
              job="{{args.service-name}}"
            }[5m]
          ))
```

### 2. Request Latency (P95)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: latency-p95
spec:
  args:
  - name: service-name
  metrics:
  - name: p95-latency
    interval: 2m
    successCondition: result < 500  # Less than 500ms
    failureLimit: 2
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          histogram_quantile(0.95,
            sum(rate(
              http_request_duration_seconds_bucket{
                job="{{args.service-name}}"
              }[5m]
            )) by (le)
          ) * 1000
```

### 3. Request Success Rate

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  args:
  - name: service-name
  metrics:
  - name: success-rate
    interval: 1m
    count: 5
    successCondition: result >= 0.95  # At least 95% success
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          sum(rate(
            http_requests_total{
              job="{{args.service-name}}",
              status=~"2.."
            }[5m]
          ))
          /
          sum(rate(
            http_requests_total{
              job="{{args.service-name}}"
            }[5m]
          ))
```

### 4. CPU Usage

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: cpu-usage
spec:
  args:
  - name: deployment-name
  - name: namespace
  metrics:
  - name: cpu-usage
    interval: 1m
    successCondition: result < 80  # Less than 80% CPU
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          sum(rate(
            container_cpu_usage_seconds_total{
              namespace="{{args.namespace}}",
              pod=~"{{args.deployment-name}}-.*"
            }[5m]
          )) by (pod)
          /
          sum(
            container_spec_cpu_quota{
              namespace="{{args.namespace}}",
              pod=~"{{args.deployment-name}}-.*"
            }
          ) by (pod) * 100
```

### 5. Memory Usage

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: memory-usage
spec:
  args:
  - name: deployment-name
  - name: namespace
  metrics:
  - name: memory-usage
    interval: 1m
    successCondition: result < 85  # Less than 85% memory
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          sum(
            container_memory_working_set_bytes{
              namespace="{{args.namespace}}",
              pod=~"{{args.deployment-name}}-.*"
            }
          )
          /
          sum(
            container_spec_memory_limit_bytes{
              namespace="{{args.namespace}}",
              pod=~"{{args.deployment-name}}-.*"
            }
          ) * 100
```

### 6. Request Rate (RPS)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: request-rate
spec:
  args:
  - name: service-name
  - name: min-rps
    value: "100"
  metrics:
  - name: request-rate
    interval: 1m
    successCondition: result >= {{args.min-rps}}
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          sum(rate(
            http_requests_total{
              job="{{args.service-name}}"
            }[1m]
          ))
```

## Advanced AnalysisTemplate Features

### 1. Multiple Metrics

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: comprehensive-check
spec:
  args:
  - name: service-name
  metrics:
  - name: error-rate
    interval: 2m
    successCondition: result < 0.05
    failureLimit: 3
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          sum(rate(http_requests_total{job="{{args.service-name}}",status=~"5.."}[5m]))
          /
          sum(rate(http_requests_total{job="{{args.service-name}}"}[5m]))
  
  - name: latency-p95
    interval: 2m
    successCondition: result < 500
    failureLimit: 2
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          histogram_quantile(0.95,
            sum(rate(http_request_duration_seconds_bucket{job="{{args.service-name}}"}[5m])) by (le)
          ) * 1000
  
  - name: cpu-usage
    interval: 1m
    successCondition: result < 80
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          sum(rate(container_cpu_usage_seconds_total{pod=~"{{args.service-name}}-.*"}[5m])) * 100
```

### 2. Initial Delay

Wait before starting analysis:
```yaml
metrics:
- name: error-rate
  initialDelay: 2m  # Wait 2 minutes before first measurement
  interval: 1m
  count: 5
  successCondition: result < 0.05
  provider:
    prometheus:
      address: http://prometheus:9090
      query: |
        rate(http_errors_total[5m])
```

### 3. Failure Limit

Number of failures before aborting:
```yaml
metrics:
- name: error-rate
  interval: 1m
  count: 10
  failureLimit: 3  # Abort after 3 failures
  successCondition: result < 0.05
  provider:
    prometheus:
      query: |
        rate(http_errors_total[5m])
```

### 4. Consecutive Errors

Require consecutive failures before aborting:
```yaml
metrics:
- name: error-rate
  interval: 1m
  consecutiveErrorLimit: 3  # Abort after 3 consecutive failures
  successCondition: result < 0.05
  provider:
    prometheus:
      query: |
        rate(http_errors_total[5m])
```

### 5. Inconclusive Limit

```yaml
metrics:
- name: error-rate
  interval: 1m
  inconclusiveLimit: 2  # Fail after 2 inconclusive results
  successCondition: result < 0.05
  failureCondition: result >= 0.10
  provider:
    prometheus:
      query: |
        rate(http_errors_total[5m])
```

### 6. DryRun Metrics

Metrics that don't affect rollout:
```yaml
spec:
  metrics:
  - name: error-rate
    successCondition: result < 0.05
    provider:
      prometheus:
        query: rate(http_errors_total[5m])
  
  dryRun:
  - name: experimental-metric
    provider:
      prometheus:
        query: some_experimental_query
```

## Template Arguments

### Using Arguments

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: parameterized-check
spec:
  args:
  - name: service-name
  - name: namespace
  - name: error-threshold
    value: "0.05"  # Default value
  - name: query-interval
    value: "2m"
  
  metrics:
  - name: error-rate
    interval: "{{args.query-interval}}"
    successCondition: result < {{args.error-threshold}}
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          sum(rate(
            http_requests_total{
              job="{{args.service-name}}",
              namespace="{{args.namespace}}",
              status=~"5.."
            }[5m]
          ))
          /
          sum(rate(
            http_requests_total{
              job="{{args.service-name}}",
              namespace="{{args.namespace}}"
            }[5m]
          ))
```

**Using in Rollout:**
```yaml
strategy:
  canary:
    analysis:
      templates:
      - templateName: parameterized-check
      args:
      - name: service-name
        value: myapp
      - name: namespace
        value: production
      - name: error-threshold
        value: "0.03"  # Override default
```

### ValueFrom - Dynamic Arguments

```yaml
args:
- name: pod-hash
  valueFrom:
    podTemplateHashValue: Latest  # Gets canary pod hash

- name: stable-hash
  valueFrom:
    podTemplateHashValue: Stable  # Gets stable pod hash

- name: service-name
  valueFrom:
    fieldRef:
      fieldPath: metadata.name

- name: namespace
  valueFrom:
    fieldRef:
      fieldPath: metadata.namespace
```

## ClusterAnalysisTemplate

Cluster-scoped version for reuse across namespaces:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ClusterAnalysisTemplate
metadata:
  name: global-error-rate
spec:
  args:
  - name: service-name
  - name: namespace
  metrics:
  - name: error-rate
    interval: 2m
    successCondition: result < 0.05
    provider:
      prometheus:
        address: http://prometheus.monitoring:9090
        query: |
          sum(rate(
            http_requests_total{
              job="{{args.service-name}}",
              namespace="{{args.namespace}}",
              status=~"5.."
            }[5m]
          ))
          /
          sum(rate(
            http_requests_total{
              job="{{args.service-name}}",
              namespace="{{args.namespace}}"
            }[5m]
          ))
```

**Usage:**
```yaml
strategy:
  canary:
    analysis:
      templates:
      - templateName: global-error-rate
        clusterScope: true
      args:
      - name: service-name
        value: myapp
```

## Testing AnalysisTemplates

### Manual AnalysisRun

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisRun
metadata:
  name: test-analysis
spec:
  metrics:
  - name: error-rate
    interval: 30s
    count: 3
    successCondition: result < 0.05
    provider:
      prometheus:
        address: http://prometheus:9090
        query: rate(http_errors_total[5m])
```

```bash
# Create and watch
kubectl apply -f test-analysisrun.yaml
kubectl get analysisrun test-analysis -w

# Check results
kubectl describe analysisrun test-analysis
```

---

**References:**
- [Analysis Documentation](https://argoproj.github.io/argo-rollouts/features/analysis/)
- [Prometheus Metrics Provider](https://argoproj.github.io/argo-rollouts/analysis/prometheus/)
