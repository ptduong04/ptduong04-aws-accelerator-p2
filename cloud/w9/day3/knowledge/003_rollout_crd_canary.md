# Rollout CRD - Canary Strategy

## Basic Canary Rollout

### Simple Example

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: myapp
  namespace: production
spec:
  replicas: 5
  revisionHistoryLimit: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: myapp:v2.0.0
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
  strategy:
    canary:
      steps:
      - setWeight: 20
      - pause: {duration: 2m}
      - setWeight: 40
      - pause: {duration: 2m}
      - setWeight: 60
      - pause: {duration: 2m}
      - setWeight: 80
      - pause: {duration: 2m}
```

**Behavior:**
1. Deploy 20% traffic to new version (canary)
2. Wait 2 minutes (automatic)
3. Increase to 40%, wait 2 minutes
4. Continue until 100%

## Canary Strategy Options

### 1. Manual Promotion

```yaml
strategy:
  canary:
    steps:
    - setWeight: 25
    - pause: {}  # Indefinite pause - requires manual promotion
    - setWeight: 50
    - pause: {}
    - setWeight: 75
    - pause: {}
```

**Promote manually:**
```bash
kubectl argo rollouts promote myapp
```

### 2. Time-Based Progression

```yaml
strategy:
  canary:
    steps:
    - setWeight: 10
    - pause: {duration: 5m}
    - setWeight: 30
    - pause: {duration: 10m}
    - setWeight: 50
    - pause: {duration: 15m}
```

### 3. Analysis-Driven Progression

```yaml
strategy:
  canary:
    steps:
    - setWeight: 20
    - pause: {duration: 1m}
    - analysis:
        templates:
        - templateName: success-rate
        args:
        - name: service-name
          value: myapp-canary
    - setWeight: 50
    - pause: {duration: 2m}
    - analysis:
        templates:
        - templateName: success-rate
        - templateName: latency-check
```

## Traffic Routing

### Without Traffic Management (Pod-Based)

**Default behavior:**
- Traffic split based on ReplicaSet ratios
- No service mesh needed
- Less precise traffic control

```yaml
strategy:
  canary:
    # No trafficRouting specified
    steps:
    - setWeight: 20  # 20% of pods will be canary
```

### With Istio

```yaml
strategy:
  canary:
    trafficRouting:
      istio:
        virtualService:
          name: myapp-vsvc
          routes:
          - primary  # VirtualService route name
        destinationRule:
          name: myapp-destrule
          canarySubsetName: canary
          stableSubsetName: stable
    steps:
    - setWeight: 20
    - pause: {duration: 2m}
```

**Required Istio Resources:**

```yaml
# VirtualService
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: myapp-vsvc
spec:
  hosts:
  - myapp.example.com
  http:
  - name: primary  # Referenced in Rollout
    route:
    - destination:
        host: myapp
        subset: stable
      weight: 100
    - destination:
        host: myapp
        subset: canary
      weight: 0
---
# DestinationRule
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: myapp-destrule
spec:
  host: myapp
  subsets:
  - name: stable
    labels:
      app: myapp
  - name: canary
    labels:
      app: myapp
```

### With Nginx Ingress

```yaml
strategy:
  canary:
    trafficRouting:
      nginx:
        stableIngress: myapp-stable
        annotationPrefix: nginx.ingress.kubernetes.io
    steps:
    - setWeight: 20
    - pause: {duration: 2m}
```

**Required Ingress:**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-stable
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-stable
            port:
              number: 80
```

### With AWS ALB

```yaml
strategy:
  canary:
    trafficRouting:
      alb:
        ingress: myapp-ingress
        servicePort: 80
        rootService: myapp-root
    steps:
    - setWeight: 20
    - pause: {duration: 2m}
```

## Advanced Canary Patterns

### 1. MaxSurge and MaxUnavailable

```yaml
strategy:
  canary:
    maxSurge: "25%"        # Max additional pods during rollout
    maxUnavailable: 0      # Minimum pods that must stay available
    steps:
    - setWeight: 25
    - pause: {duration: 2m}
```

### 2. Anti-Affinity for Canary

Ensure canary pods are on different nodes:

```yaml
spec:
  template:
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - myapp
              topologyKey: kubernetes.io/hostname
```

### 3. Scoped Analysis

Run analysis specific to canary pods:

```yaml
strategy:
  canary:
    analysis:
      templates:
      - templateName: error-rate
      args:
      - name: service
        value: myapp
      - name: pod-hash
        valueFrom:
          podTemplateHashValue: Latest  # Canary pods only
    steps:
    - setWeight: 25
    - pause: {duration: 5m}
```

### 4. Background Analysis

Analysis runs continuously throughout rollout:

```yaml
strategy:
  canary:
    analysis:
      templates:
      - templateName: continuous-error-check
      startingStep: 1  # Start after first step
    steps:
    - setWeight: 20
    - pause: {duration: 2m}
    - setWeight: 40
    - pause: {duration: 2m}
```

### 5. Multi-Stage Analysis

Different checks at different stages:

```yaml
strategy:
  canary:
    steps:
    - setWeight: 10
    - analysis:
        templates:
        - templateName: smoke-test  # Initial validation
    - setWeight: 30
    - pause: {duration: 5m}
    - analysis:
        templates:
        - templateName: performance-test  # Deeper validation
    - setWeight: 60
    - pause: {duration: 10m}
```

## Step Types

### 1. setWeight

Set traffic percentage to canary:
```yaml
- setWeight: 40  # 40% to canary
```

### 2. pause

Pause rollout:
```yaml
- pause: {}                    # Indefinite
- pause: {duration: 5m}        # 5 minutes
- pause: {duration: 1h}        # 1 hour
```

### 3. setCanaryScale

Override replica count for canary:
```yaml
- setCanaryScale:
    replicas: 3              # Explicit count
- setCanaryScale:
    weight: 25               # Percentage of spec.replicas
- setCanaryScale:
    matchTrafficWeight: true # Match traffic weight
```

### 4. analysis

Run analysis:
```yaml
- analysis:
    templates:
    - templateName: my-analysis
    args:
    - name: param1
      value: value1
```

### 5. experiment

Run experiment (advanced):
```yaml
- experiment:
    duration: 10m
    templates:
    - name: canary-test
      specRef: canary
      weight: 25
```

## Complete Example with All Features

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: production-app
spec:
  replicas: 10
  revisionHistoryLimit: 5
  selector:
    matchLabels:
      app: production-app
  template:
    metadata:
      labels:
        app: production-app
    spec:
      containers:
      - name: app
        image: myapp:v2.0.0
        ports:
        - containerPort: 8080
          protocol: TCP
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 10
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 1000m
            memory: 512Mi
  strategy:
    canary:
      maxSurge: "25%"
      maxUnavailable: 0
      trafficRouting:
        istio:
          virtualService:
            name: production-app-vsvc
            routes:
            - primary
          destinationRule:
            name: production-app-destrule
            canarySubsetName: canary
            stableSubsetName: stable
      analysis:
        templates:
        - templateName: background-analysis
        startingStep: 1
        args:
        - name: service-name
          value: production-app
      steps:
      # Stage 1: Initial rollout (10%)
      - setWeight: 10
      - pause: {duration: 2m}
      - analysis:
          templates:
          - templateName: smoke-test
      
      # Stage 2: Early validation (25%)
      - setWeight: 25
      - pause: {duration: 5m}
      - analysis:
          templates:
          - templateName: error-rate-check
          - templateName: latency-check
      
      # Stage 3: Moderate traffic (50%)
      - setWeight: 50
      - pause: {duration: 10m}
      - analysis:
          templates:
          - templateName: comprehensive-check
      
      # Stage 4: High traffic (75%)
      - setWeight: 75
      - pause: {duration: 10m}
      
      # Stage 5: Manual approval before 100%
      - pause: {}
      
      # Full rollout
      - setWeight: 100
```

## Monitoring Rollout Status

```bash
# Watch rollout live
kubectl argo rollouts get rollout production-app --watch

# Check status
kubectl get rollout production-app

# View events
kubectl describe rollout production-app

# Check ReplicaSets
kubectl get rs -l app=production-app

# View analysis runs
kubectl get analysisrun
```

---

**References:**
- [Canary Strategy Documentation](https://argoproj.github.io/argo-rollouts/features/canary/)
- [Traffic Management](https://argoproj.github.io/argo-rollouts/features/traffic-management/)
