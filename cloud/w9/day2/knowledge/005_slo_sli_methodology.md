# SLO/SLI Methodology

## Definitions

### SLI (Service Level Indicator)

Metric đo lường service performance

Examples:
- Request latency
- Error rate
- Availability
- Throughput

SLI must be:
- Measurable
- Actionable
- User-centric

### SLO (Service Level Objective)

Target value cho SLI

Format: "X% của requests phải đạt Y trong Z time window"

Examples:
- 99.9% requests có latency < 500ms
- 99.95% requests thành công (error rate < 0.05%)
- 99.5% uptime per month

### SLA (Service Level Agreement)

Contract với customer, có consequences nếu vi phạm

Example:
```
SLA: 99.9% uptime per month
- Below 99.9%: 10% refund
- Below 99%: 25% refund
- Below 95%: 100% refund
```

Relationship:
```
SLI → measurement
SLO → internal target (stricter than SLA)
SLA → external promise
```

## Why SLOs Matter

### Without SLOs

Team không biết:
- Service đang healthy?
- Deploy có risk không?
- Priority fix bug nào?

Result:
- Over-engineer (aim for 100% uptime)
- Alert fatigue (too many alerts)
- Không biết trade-offs

### With SLOs

Clear target:
- 99.9% availability = OK với 43 minutes downtime/month
- Còn error budget → safe deploy
- Hết error budget → freeze features, focus stability

Benefits:
- Balance reliability vs velocity
- Data-driven decisions
- Clear priorities

## Choosing SLIs

### User Journey Based

Think từ user perspective:
```
User story: "Tôi muốn xem profile"

Journey:
1. Click profile button
2. Send API request
3. Receive data
4. Render page

SLIs:
- Latency: Request → response time
- Availability: Request success rate
- Correctness: Data accuracy
```

### Common SLIs

**Availability:**
```
successful_requests / total_requests
```

**Latency:**
```
p50, p95, p99 response time
```

**Quality:**
```
correct_responses / total_responses
```

**Throughput:**
```
requests per second
```

### SLI Menu

Google SRE book suggests menu approach:

Request-driven:
- Availability
- Latency
- Quality

Data processing:
- Coverage (% data processed)
- Correctness
- Freshness (data age)
- Throughput

Storage:
- Durability (data loss)
- Availability (read/write success)
- Latency

## Setting SLO Targets

### Start with Current Performance

Example:
```
Current state:
- p95 latency: 300ms
- Availability: 99.95%

Initial SLOs:
- p95 latency < 500ms (comfortable buffer)
- Availability > 99.9% (slightly lower)
```

Không aim too high initially, iterate sau

### Consider Impact

```
99% availability   = 7.2 hours downtime/month
99.9% availability = 43 minutes downtime/month
99.95% availability = 21 minutes downtime/month
99.99% availability = 4.3 minutes downtime/month
```

Each nine costs:
- More infrastructure
- More complex deployments
- Slower feature velocity

Question: Cost-benefit có worth không?

### Multiple SLOs

Typical service:
```yaml
SLOs:
  - name: API Availability
    target: 99.9%
    window: 30 days
    
  - name: API Latency P95
    target: 500ms
    window: 30 days
    
  - name: API Latency P99
    target: 1000ms
    window: 30 days
    
  - name: Background Jobs Success Rate
    target: 99%
    window: 7 days
```

Different SLOs cho different priorities

## Error Budgets

### Concept

Error budget = 1 - SLO

```
SLO: 99.9% availability
Error budget: 0.1% = 43 minutes/month
```

Budget remaining:
```
current_error_rate < error_budget → OK, deploy features
current_error_rate ≥ error_budget → STOP, fix reliability
```

### Tracking

```
Error budget consumed = (1 - actual_uptime) / (1 - SLO)

Example:
SLO: 99.9% (budget: 0.1%)
Actual: 99.85%
Consumed: (1 - 0.9985) / (1 - 0.999) = 0.15 / 0.1 = 150%

→ Over budget! Freeze features
```

### Policy

```markdown
Error Budget Policy

If error budget > 50% remaining:
- Ship features normally
- Take calculated risks
- Experiment with new tech

If error budget 25-50% remaining:
- Slow down feature work
- Increase testing
- Review incidents

If error budget < 25% remaining:
- Feature freeze
- Focus on reliability only
- Post-mortems for all incidents
- No risky changes

If error budget exhausted:
- Complete freeze
- War room mode
- Executive escalation
```

## SLO Implementation

### Measure SLIs

Prometheus example:
```yaml
# Availability SLI
- record: sli:availability:ratio
  expr: |
    sum(rate(http_requests_total{status!~"5.."}[5m]))
    /
    sum(rate(http_requests_total[5m]))

# Latency SLI (% requests under threshold)
- record: sli:latency:ratio
  expr: |
    sum(rate(http_request_duration_seconds_bucket{le="0.5"}[5m]))
    /
    sum(rate(http_request_duration_seconds_count[5m]))
```

### Calculate SLO Compliance

```yaml
# 30-day rolling window
- record: slo:availability:30d
  expr: |
    avg_over_time(sli:availability:ratio[30d])

# Error budget remaining
- record: slo:error_budget:availability:30d
  expr: |
    1 - (
      (1 - avg_over_time(sli:availability:ratio[30d]))
      /
      (1 - 0.999)  # SLO target
    )
```

### Visualization

Grafana dashboard:
```
Panel 1: Current SLI value
  sli:availability:ratio

Panel 2: SLO target line
  Threshold at 0.999

Panel 3: Error budget remaining
  slo:error_budget:availability:30d
  - Green: > 50%
  - Yellow: 25-50%
  - Red: < 25%

Panel 4: Budget burn rate
  Rate of error budget consumption
```

## Multi-Window Burn Rate Alerts

### Problem với Simple Alerts

Alert đơn giản:
```yaml
alert: HighErrorRate
expr: error_rate > 0.001
```

Issues:
- False positives: Short spikes
- Slow detection: Gradual degradation

### Burn Rate Concept

Burn rate = Speed of consuming error budget

```
Normal burn rate = 1
2x burn rate → exhaust budget in 15 days (30-day window)
10x burn rate → exhaust budget in 3 days
```

### Multi-Window Approach

Check 2 windows:
1. Short window: Detect current issue
2. Long window: Confirm it's sustained

Example:
```yaml
# Fast burn (36x rate)
alert: ErrorBudgetBurnFast
expr: |
  (
    sum(rate(http_requests_total{status=~"5.."}[1h]))
    /
    sum(rate(http_requests_total[1h]))
  ) > (14.4 * 0.001)  # 36x of 0.1% budget
  and
  (
    sum(rate(http_requests_total{status=~"5.."}[5m]))
    /
    sum(rate(http_requests_total[5m]))
  ) > (14.4 * 0.001)
for: 2m
labels:
  severity: critical
annotations:
  summary: "Fast error budget burn (1h/5m windows)"

# Slow burn (6x rate)
alert: ErrorBudgetBurnSlow
expr: |
  (
    sum(rate(http_requests_total{status=~"5.."}[6h]))
    /
    sum(rate(http_requests_total[6h]))
  ) > (6 * 0.001)
  and
  (
    sum(rate(http_requests_total{status=~"5.."}[30m]))
    /
    sum(rate(http_requests_total[30m]))
  ) > (6 * 0.001)
for: 15m
labels:
  severity: warning
annotations:
  summary: "Slow error budget burn (6h/30m windows)"
```

### Multiple Tiers

Full implementation:
```yaml
# Tier 1: Extreme burn (36x)
# Will exhaust budget in 20 hours
- alert: ErrorBudgetBurnExtreme
  expr: |
    burn_rate_1h > 36 and burn_rate_5m > 36
  for: 2m
  severity: page

# Tier 2: Fast burn (10x)
# Will exhaust budget in 3 days
- alert: ErrorBudgetBurnFast
  expr: |
    burn_rate_6h > 10 and burn_rate_30m > 10
  for: 15m
  severity: page

# Tier 3: Medium burn (5x)
# Will exhaust budget in 6 days
- alert: ErrorBudgetBurnMedium
  expr: |
    burn_rate_24h > 5 and burn_rate_2h > 5
  for: 1h
  severity: ticket

# Tier 4: Slow burn (2x)
# Will exhaust budget in 15 days
- alert: ErrorBudgetBurnSlow
  expr: |
    burn_rate_3d > 2 and burn_rate_6h > 2
  for: 3h
  severity: ticket
```

Benefits:
- Fast detection (1h + 5m windows)
- No false positives (require both windows)
- Graduated severity (extreme → slow)
- Actionable timeframes

## Real-World Example

E-commerce API:

### Define SLIs/SLOs

```yaml
service: checkout-api

SLIs:
  - name: availability
    description: Successful requests
    query: |
      sum(rate(http_requests{job="checkout-api",status!~"5.."}[5m]))
      /
      sum(rate(http_requests{job="checkout-api"}[5m]))
  
  - name: latency_p95
    description: 95th percentile latency
    query: |
      histogram_quantile(0.95,
        sum(rate(http_request_duration_seconds_bucket{job="checkout-api"}[5m])) by (le)
      )

SLOs:
  - name: availability
    target: 99.9%
    window: 30d
    error_budget: 0.1%
  
  - name: latency_p95
    target: 500ms
    window: 30d
    error_budget: 0.1%
```

### Implement Monitoring

```yaml
# Recording rules
groups:
  - name: checkout_sli
    interval: 30s
    rules:
      - record: checkout:availability:5m
        expr: |
          sum(rate(http_requests{job="checkout-api",status!~"5.."}[5m]))
          /
          sum(rate(http_requests{job="checkout-api"}[5m]))
      
      - record: checkout:latency_good:5m
        expr: |
          sum(rate(http_request_duration_seconds_bucket{job="checkout-api",le="0.5"}[5m]))
          /
          sum(rate(http_request_duration_seconds_count{job="checkout-api"}[5m]))

  - name: checkout_slo
    interval: 5m
    rules:
      - record: checkout:availability:30d
        expr: avg_over_time(checkout:availability:5m[30d])
      
      - record: checkout:error_budget:availability:30d
        expr: |
          1 - (
            (1 - checkout:availability:30d) / (1 - 0.999)
          )
```

### Alerting

```yaml
groups:
  - name: checkout_alerts
    rules:
      # Fast burn
      - alert: CheckoutErrorBudgetBurnFast
        expr: |
          (1 - checkout:availability:5m) > (14.4 * 0.001)
          and
          (1 - avg_over_time(checkout:availability:5m[1h])) > (14.4 * 0.001)
        for: 2m
        labels:
          severity: critical
          service: checkout-api
        annotations:
          summary: "Checkout API burning error budget fast"
          description: "Error budget will be exhausted in < 24h at this rate"
          runbook: "https://wiki/runbooks/checkout-error-budget"
      
      # Slow burn
      - alert: CheckoutErrorBudgetBurnSlow
        expr: |
          (1 - checkout:availability:5m) > (6 * 0.001)
          and
          (1 - avg_over_time(checkout:availability:5m[6h])) > (6 * 0.001)
        for: 15m
        labels:
          severity: warning
          service: checkout-api
        annotations:
          summary: "Checkout API burning error budget slowly"
          description: "Error budget will be exhausted in < 5 days"
      
      # Budget exhausted
      - alert: CheckoutErrorBudgetExhausted
        expr: checkout:error_budget:availability:30d < 0
        for: 5m
        labels:
          severity: critical
          service: checkout-api
        annotations:
          summary: "Checkout API error budget exhausted"
          description: "Feature freeze in effect until budget recovers"
```

### Dashboard

Grafana panels:
```
1. Error Budget Status
   - Gauge: checkout:error_budget:availability:30d
   - Green > 50%, Yellow 25-50%, Red < 25%

2. Current Availability
   - Graph: checkout:availability:5m
   - SLO line at 0.999

3. Burn Rate
   - Graph: (1 - checkout:availability:5m) / 0.001
   - Show 1x, 2x, 10x lines

4. Budget Remaining Days
   - Stat: (checkout:error_budget:availability:30d * 30)
   - At current burn rate

5. Latency P95
   - Graph: checkout:latency_p95
   - Threshold at 500ms

6. Recent Incidents
   - Table: ALERTS{service="checkout-api"}
```

## Best Practices

1. Start simple
   - 1-2 SLOs initially
   - Iterate based on learning

2. User-centric SLIs
   - Measure what users experience
   - Not internal metrics

3. Realistic targets
   - Based on current performance
   - Account for dependencies

4. Error budget policy
   - Clear actions at thresholds
   - Enforce consistently

5. Review regularly
   - Quarterly SLO review
   - Adjust based on business needs

6. Multi-window alerts
   - Fast detection
   - Reduce false positives

7. Document everything
   - Why these SLOs?
   - How calculated?
   - What to do when violated?

8. Automate enforcement
   - Block deploys when budget low
   - Auto-rollback on SLO violation
