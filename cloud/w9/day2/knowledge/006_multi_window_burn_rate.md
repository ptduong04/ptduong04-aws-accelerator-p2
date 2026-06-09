# Multi-Window Burn Rate Alerts

## Problem với Traditional Alerts

### Threshold-Based Alerts

Traditional approach:
```yaml
alert: HighErrorRate
expr: error_rate > 0.01
for: 5m
```

Issues:

**1. False Positives:**
```
Scenario: Traffic spike
10:00 → 100 requests, 2 errors = 2% (alert!)
10:05 → normal traffic

Result: Alert but không có real problem
```

**2. Slow Detection:**
```
Scenario: Gradual degradation
Day 1: 0.5% error rate (no alert)
Day 2: 0.7% error rate (no alert)
Day 3: 0.9% error rate (no alert)
Day 4: 1.1% error rate (ALERT!)

Result: 3 days burn error budget trước khi detect
```

**3. No Context:**
Alert không nói:
- Impact on SLO?
- Urgent hay có thể đợi?
- Bao lâu until problem?

## Burn Rate Concept

### Definition

Burn rate = Speed of consuming error budget

```
Error budget = 1 - SLO

SLO: 99.9%
Error budget: 0.1%
Time window: 30 days

Normal burn rate = 1
  → Exhaust budget in exactly 30 days
  → Error rate = 0.1%

2x burn rate = 2
  → Exhaust budget in 15 days
  → Error rate = 0.2%

10x burn rate = 10
  → Exhaust budget in 3 days
  → Error rate = 1%
```

Formula:
```
burn_rate = current_error_rate / error_budget
```

### Why Burn Rate

Benefits:
- Normalized metric (easy compare across services)
- Time to exhaustion (actionable)
- Severity levels (graduated response)

Example:
```
Service A: SLO 99.9%, error rate 0.5%
  burn_rate = 0.5% / 0.1% = 5x
  
Service B: SLO 99%, error rate 0.5%
  burn_rate = 0.5% / 1% = 0.5x

Service A more urgent despite same error rate
```

## Multi-Window Strategy

### Single Window Problem

```yaml
alert: HighBurnRate
expr: burn_rate > 10
```

Issue: One anomalous minute triggers alert

### Two Windows

Check both:
1. Long window: Sustained problem
2. Short window: Still happening

```yaml
alert: HighBurnRate
expr: |
  burn_rate_1h > 10    # Sustained over 1h
  and
  burn_rate_5m > 10    # Still happening now
```

Benefits:
- Long window: Filter noise
- Short window: Confirm current
- Both: High confidence

### Window Sizing

Google SRE recommendations:

```
Burn Rate | Long Window | Short Window | Alert After
----------|-------------|--------------|-------------
36x       | 1h          | 5m           | 2m
10x       | 6h          | 30m          | 15m
5x        | 24h         | 2h           | 1h
2x        | 3d          | 6h           | 3h
```

Logic:
- Faster burn → shorter windows, faster alert
- Slower burn → longer windows, confirm trend

## Implementation

### Calculate Burn Rate

```yaml
groups:
  - name: burn_rate
    interval: 30s
    rules:
      # Error ratio (1 - availability)
      - record: job:error_ratio:5m
        expr: |
          1 - (
            sum(rate(http_requests{status!~"5.."}[5m]))
            /
            sum(rate(http_requests[5m]))
          )
      
      - record: job:error_ratio:30m
        expr: |
          1 - (
            sum(rate(http_requests{status!~"5.."}[30m]))
            /
            sum(rate(http_requests[30m]))
          )
      
      - record: job:error_ratio:1h
        expr: |
          1 - (
            sum(rate(http_requests{status!~"5.."}[1h]))
            /
            sum(rate(http_requests[1h]))
          )
      
      - record: job:error_ratio:6h
        expr: |
          1 - (
            sum(rate(http_requests{status!~"5.."}[6h]))
            /
            sum(rate(http_requests[6h]))
          )
      
      # Burn rates (error_ratio / error_budget)
      - record: job:burn_rate:5m
        expr: job:error_ratio:5m / 0.001  # SLO 99.9%
      
      - record: job:burn_rate:30m
        expr: job:error_ratio:30m / 0.001
      
      - record: job:burn_rate:1h
        expr: job:error_ratio:1h / 0.001
      
      - record: job:burn_rate:6h
        expr: job:error_ratio:6h / 0.001
```

### Alert Rules

```yaml
groups:
  - name: slo_alerts
    rules:
      # Page immediately - exhausts budget in < 1 day
      - alert: ErrorBudgetBurnExtreme
        expr: |
          job:burn_rate:1h > 36
          and
          job:burn_rate:5m > 36
        for: 2m
        labels:
          severity: critical
          page: "true"
        annotations:
          summary: "Extreme error budget burn (36x)"
          description: |
            Current burn rate will exhaust monthly budget in 20 hours.
            Error rate: {{ $value | humanizePercentage }}
            Action: Immediate investigation required
          runbook_url: "https://runbooks/error-budget-extreme"
      
      # Page - exhausts budget in < 3 days
      - alert: ErrorBudgetBurnFast
        expr: |
          job:burn_rate:6h > 10
          and
          job:burn_rate:30m > 10
        for: 15m
        labels:
          severity: critical
          page: "true"
        annotations:
          summary: "Fast error budget burn (10x)"
          description: |
            Current burn rate will exhaust monthly budget in 3 days.
            Error rate: {{ $value | humanizePercentage }}
            Action: Investigation within 1 hour
          runbook_url: "https://runbooks/error-budget-fast"
      
      # Ticket - exhausts budget in < 6 days
      - alert: ErrorBudgetBurnMedium
        expr: |
          job:burn_rate:24h > 5
          and
          job:burn_rate:2h > 5
        for: 1h
        labels:
          severity: warning
          ticket: "true"
        annotations:
          summary: "Medium error budget burn (5x)"
          description: |
            Current burn rate will exhaust monthly budget in 6 days.
            Error rate: {{ $value | humanizePercentage }}
            Action: Investigation within 24 hours
          runbook_url: "https://runbooks/error-budget-medium"
      
      # Ticket - exhausts budget in < 15 days
      - alert: ErrorBudgetBurnSlow
        expr: |
          job:burn_rate:3d > 2
          and
          job:burn_rate:6h > 2
        for: 3h
        labels:
          severity: info
          ticket: "true"
        annotations:
          summary: "Slow error budget burn (2x)"
          description: |
            Current burn rate will exhaust monthly budget in 15 days.
            Error rate: {{ $value | humanizePercentage }}
            Action: Monitor and investigate root cause
          runbook_url: "https://runbooks/error-budget-slow"
```

### Latency SLO

Same approach cho latency:

```yaml
# Latency SLO: 95% requests < 500ms
# Good events: requests under threshold
- record: job:latency_good_ratio:5m
  expr: |
    sum(rate(http_request_duration_seconds_bucket{le="0.5"}[5m]))
    /
    sum(rate(http_request_duration_seconds_count[5m]))

# Bad events ratio
- record: job:latency_bad_ratio:5m
  expr: 1 - job:latency_good_ratio:5m

# Burn rate
- record: job:latency_burn_rate:5m
  expr: job:latency_bad_ratio:5m / 0.05  # Budget 5%

# Alerts
- alert: LatencyBudgetBurnFast
  expr: |
    job:latency_burn_rate:1h > 10
    and
    job:latency_burn_rate:5m > 10
  for: 15m
```

## Real-World Scenarios

### Scenario 1: Traffic Spike

```
Time: 10:00
Event: Sudden traffic increase
Metrics:
  - 5m error rate: 2% (20x burn)
  - 1h error rate: 0.5% (5x burn)

Alert: NO
Reason: Long window không exceed threshold
Action: Monitor, likely transient
```

### Scenario 2: Deploy Regression

```
Time: 14:00
Event: Bad deploy
Metrics:
  14:05
    - 5m error rate: 3% (30x burn)
    - 1h error rate: 0.2% (2x burn)
  Alert: NO (long window low)
  
  14:30
    - 5m error rate: 3% (30x burn)
    - 1h error rate: 1.5% (15x burn)
  Alert: YES (both windows high)
  
  14:35
    - Rollback deployed
  
  14:40
    - 5m error rate: 0.1% (1x burn)
    - 1h error rate: 1.2% (12x burn)
  Alert: NO (short window recovered)
```

Fast detection (30 min) + auto-resolve

### Scenario 3: Gradual Degradation

```
Day 1:
  - Error rate: 0.3% (3x burn)
  - Slow alert: NO (need sustained)

Day 2:
  - Error rate: 0.4% (4x burn)
  - Slow alert: NO

Day 3:
  - 6h burn rate: 4x
  - 3d burn rate: 3.5x
  - Slow alert: YES

Action: Less urgent, có time investigate
```

### Scenario 4: Intermittent Issues

```
Pattern: 5% error rate every 15 minutes for 1 minute

Without multi-window:
  - Alert every 15 min
  - Alert fatigue

With multi-window:
  - 5m: High during spike
  - 1h: Averaged out
  - Alert: NO or LOW severity
  
Action: Different alert cho intermittent patterns
```

## Advanced Patterns

### Composite SLOs

Multiple SLIs combined:

```yaml
# Good event = success AND fast
- record: composite:good_ratio:5m
  expr: |
    sum(rate(http_requests{status!~"5..",duration_bucket_le="0.5"}[5m]))
    /
    sum(rate(http_requests[5m]))

# Burn rate
- record: composite:burn_rate:5m
  expr: (1 - composite:good_ratio:5m) / 0.001
```

### Per-Endpoint SLOs

Different thresholds:

```yaml
# Critical endpoint (strict)
- alert: CheckoutBudgetBurnFast
  expr: |
    burn_rate{endpoint="/checkout"} > 5  # Stricter
    ...

# Less critical endpoint (relaxed)
- alert: AdminBudgetBurnFast
  expr: |
    burn_rate{endpoint="/admin"} > 20  # More relaxed
    ...
```

### Time-Based SLOs

Different targets based on time:

```yaml
# Business hours: strict SLO
- record: slo:target:current
  expr: |
    (
      0.999  # 99.9% during business hours (8am-8pm)
      and
      hour() >= 8 and hour() < 20
    )
    or
    (
      0.995  # 99.5% off-hours
      and
      (hour() < 8 or hour() >= 20)
    )
```

### Multi-Burn Rate Dashboard

Grafana dashboard structure:

```
Panel 1: Current Burn Rate
  - Gauge showing real-time burn
  - Zones: Green (<1x), Yellow (1-5x), Red (>5x)

Panel 2: Burn Rate Heatmap
  - X-axis: Time
  - Y-axis: Burn rate levels
  - Color: Intensity

Panel 3: Multi-Window Status
  - Table:
    Window | Burn Rate | Status | Time to Exhaust
    5m     | 2x        | OK     | 15 days
    1h     | 1.5x      | OK     | 20 days
    6h     | 1.2x      | OK     | 25 days

Panel 4: Error Budget Projection
  - Line chart: Projected budget depletion
  - Based on current burn rate

Panel 5: Alert History
  - Timeline of burn rate alerts
  - Color-coded by severity
```

## Tuning Alerts

### Reducing False Positives

Adjust `for` duration:
```yaml
# Too sensitive
for: 1m

# Better
for: 5m  # 5 consecutive minutes
```

Adjust burn rate multipliers:
```yaml
# Too sensitive
burn_rate > 2

# Better for your service
burn_rate > 5
```

### Reducing False Negatives

Add more tiers:
```yaml
# Only extreme
36x → page

# Better coverage
36x → page immediately
10x → page within 1h
5x → ticket within 1 day
2x → ticket within 3 days
```

### Seasonal Adjustments

Handle known patterns:

```yaml
# Lower threshold during maintenance window
- alert: ErrorBudgetBurnFast
  expr: |
    burn_rate > (
      5 * (1 + on() label_replace(
        (maintenance_window == 1) * 2,  # 3x during maintenance
        "multiplier", "$1", "", ""
      ))
    )
```

## Monitoring the Monitor

Track alert quality:

```yaml
# Alert fired
- record: alert:fired:count
  expr: count(ALERTS{alertname=~".*BudgetBurn.*"})

# Alert accuracy (actual impact)
- record: alert:accuracy
  expr: |
    (budget_consumed_during_alert / total_budget)
    /
    (alert_duration / total_duration)

# Alert fatigue (too many alerts)
- record: alert:frequency
  expr: rate(alert:fired:count[1d])
```

Review monthly:
- False positive rate
- True positive rate
- Time to detection
- Alert resolution time

Iterate thresholds based on data

## Summary

Multi-window burn rate alerts provide:

**Precision:**
- Two windows filter noise
- High confidence in alerts

**Speed:**
- Fast detection (minutes for critical)
- Graduated response

**Context:**
- Burn rate → time to exhaustion
- Severity tiers → clear priority
- Runbooks → clear action

**Reliability:**
- Fewer false positives
- Catch gradual degradation
- No alert fatigue

Implementation:
1. Define SLOs
2. Calculate burn rates (multiple windows)
3. Set up tiered alerts (36x, 10x, 5x, 2x)
4. Create runbooks
5. Monitor và tune

Result: High-quality alerts that drive action
