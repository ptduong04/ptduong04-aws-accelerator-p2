# Argo Rollouts Architecture

## Overview

Argo Rollouts is a Kubernetes controller and CRD that provides advanced deployment capabilities like Canary and Blue-Green deployments with automated progressive delivery.

## Architecture Components

```
┌─────────────────────────────────────────────────────┐
│                    Argo Rollouts                     │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────┐ │
│  │   Rollout    │  │  Analysis    │  │ Experiment│ │
│  │  Controller  │  │  Controller  │  │ Controller│ │
│  └──────────────┘  └──────────────┘  └───────────┘ │
└─────────────────────────────────────────────────────┘
           ↓                  ↓                ↓
┌──────────────────────────────────────────────────────┐
│              Kubernetes Resources                     │
│  ┌─────────┐  ┌─────────────┐  ┌──────────────────┐ │
│  │ Rollout │  │ ReplicaSet  │  │  AnalysisRun     │ │
│  │   CRD   │→ │  (stable)   │  │                  │ │
│  └─────────┘  │  (canary)   │  └──────────────────┘ │
│               └─────────────┘                        │
└──────────────────────────────────────────────────────┘
           ↓
┌──────────────────────────────────────────────────────┐
│         Traffic Management Layer                      │
│  ┌─────────┐  ┌─────────┐  ┌──────┐  ┌──────────┐  │
│  │  Istio  │  │  Nginx  │  │ ALB  │  │ Traefik  │  │
│  └─────────┘  └─────────┘  └──────┘  └──────────┘  │
└──────────────────────────────────────────────────────┘
           ↓
┌──────────────────────────────────────────────────────┐
│         Metrics Providers                             │
│  ┌────────────┐  ┌──────────┐  ┌─────────────────┐ │
│  │ Prometheus │  │ Datadog  │  │  New Relic      │ │
│  └────────────┘  └──────────┘  └─────────────────┘ │
└──────────────────────────────────────────────────────┘
```

## Core Components

### 1. Rollout Controller

**Responsibilities:**
- Watches Rollout CRD resources
- Manages ReplicaSets lifecycle
- Controls traffic splitting
- Triggers analysis runs
- Handles pause/resume/abort

**Key Functions:**
```go
// Pseudo-code representation
func (c *RolloutController) Reconcile(rollout *Rollout) {
    if rollout.NeedsUpdate() {
        c.CreateCanaryReplicaSet()
        c.UpdateTrafficWeights()
        c.CreateAnalysisRun()
        c.ProcessRolloutSteps()
    }
}
```

### 2. Analysis Controller

**Responsibilities:**
- Executes metric queries
- Evaluates success/failure criteria
- Reports results back to Rollout
- Manages retry logic

**Workflow:**
```
AnalysisTemplate → AnalysisRun → MetricProvider Query
                                       ↓
                            Success/Failure/Inconclusive
                                       ↓
                              Update Rollout Status
```

### 3. Experiment Controller (Optional)

Used for advanced scenarios like A/B testing with ephemeral environments.

## Custom Resource Definitions (CRDs)

### 1. Rollout

Replacement for Kubernetes Deployment with progressive delivery capabilities.

**Key Fields:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
spec:
  replicas: 5
  strategy:
    canary: {}      # or blueGreen: {}
  template:         # Pod template
  revisionHistoryLimit: 5
  selector:
    matchLabels:
      app: myapp
```

**Status Fields:**
- `currentPodHash`: Current stable version
- `canaryWeight`: Current traffic weight
- `conditions`: Health status
- `phase`: Progressing/Paused/Degraded/Healthy

### 2. AnalysisTemplate

Reusable metric analysis definition.

**Structure:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
spec:
  args: []           # Template parameters
  metrics: []        # Metric definitions
  dryRun: []         # Dry-run metrics
  measurementRetention: []
```

### 3. AnalysisRun

Instance of analysis execution.

**Created:**
- Automatically during Rollout
- Manually via kubectl/API
- By experiments

**States:**
- Running
- Successful
- Failed
- Error
- Inconclusive

### 4. ClusterAnalysisTemplate

Cluster-scoped version of AnalysisTemplate (shared across namespaces).

## Traffic Management Integration

### Istio Integration

**VirtualService Manipulation:**
```yaml
spec:
  strategy:
    canary:
      trafficRouting:
        istio:
          virtualService:
            name: myapp-vsvc
            routes:
            - primary
          destinationRule:
            name: myapp-destrule
            canarySubsetName: canary
            stableSubsetName: stable
```

**How it works:**
1. Rollout updates VirtualService weights
2. Istio Envoy proxies adjust traffic
3. Canary pods receive specified percentage

### Nginx Ingress Integration

**Annotation-Based Control:**
```yaml
spec:
  strategy:
    canary:
      trafficRouting:
        nginx:
          stableIngress: myapp-stable
          annotationPrefix: nginx.ingress.kubernetes.io
```

**Mechanism:**
- Creates canary Ingress with annotations
- `nginx.ingress.kubernetes.io/canary-weight: "20"`
- Nginx controller routes traffic accordingly

### ALB Integration

**AWS Load Balancer Controller:**
```yaml
spec:
  strategy:
    canary:
      trafficRouting:
        alb:
          ingress: myapp-ingress
          servicePort: 80
```

## Installation

### Using kubectl

```bash
# Install CRDs and controller
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
```

### Using Helm

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm install argo-rollouts argo/argo-rollouts -n argo-rollouts --create-namespace
```

### Install kubectl Plugin

```bash
# Download plugin
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64

# Make executable and move to PATH
chmod +x kubectl-argo-rollouts-linux-amd64
sudo mv kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts

# Verify
kubectl argo rollouts version
```

## kubectl Plugin Commands

```bash
# List rollouts
kubectl argo rollouts list rollouts -n <namespace>

# Get rollout status
kubectl argo rollouts get rollout <name> -n <namespace>

# Watch rollout progress
kubectl argo rollouts get rollout <name> --watch

# Promote rollout
kubectl argo rollouts promote <name>

# Abort rollout
kubectl argo rollouts abort <name>

# Restart rollout
kubectl argo rollouts restart <name>

# Set image
kubectl argo rollouts set image <name> <container>=<image>

# View dashboard
kubectl argo rollouts dashboard
```

## Rollout Lifecycle

### Phase Transitions

```
Healthy → Progressing → Paused → Progressing → Healthy
            ↓                                     ↑
        Degraded → Abort → Stable ───────────────┘
```

**Healthy**: All pods running, traffic stable
**Progressing**: Rollout in progress
**Paused**: Waiting for manual promotion or analysis
**Degraded**: Issues detected, may abort
**Abort**: Rollout cancelled, traffic back to stable

### ReplicaSet Management

```
Update triggers new ReplicaSet:

Stable RS:  [v1] replicas: 5 → 4 → 3 → 2 → 1 → 0
Canary RS:  [v2] replicas: 0 → 1 → 2 → 3 → 4 → 5
Traffic:         0% → 20% → 40% → 60% → 80% → 100%
```

## Configuration Best Practices

1. **Set Resource Limits**: Prevent resource exhaustion during rollout
2. **Configure Probes**: Ensure health checks before traffic
3. **Revision History**: Keep sufficient revisions for rollback
4. **Anti-Affinity**: Spread canary pods across nodes
5. **PodDisruptionBudget**: Maintain availability during rollout

## Monitoring

### Prometheus Metrics

Argo Rollouts exposes metrics:
```
rollout_phase{namespace, name, phase}
rollout_info{namespace, name, strategy}
rollout_analysis_run_result{namespace, name, phase}
```

### Events

Check Kubernetes events:
```bash
kubectl get events -n <namespace> --field-selector involvedObject.name=<rollout-name>
```

---

**References:**
- [Argo Rollouts Concepts](https://argoproj.github.io/argo-rollouts/concepts/)
- [Architecture Documentation](https://argoproj.github.io/argo-rollouts/architecture/)
