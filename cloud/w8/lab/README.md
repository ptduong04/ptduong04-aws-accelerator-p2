# Lab - Mini K8s Platform on Minikube

**Date:** 04/06/2026 - 05/06/2026

## Objective
Build a minimal Kubernetes platform running on minikube with:
- Frontend service
- Backend API service
- Database
- Configuration management
- Network policies

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│              Minikube Cluster                    │
│                                                  │
│  ┌──────────────┐         ┌──────────────┐     │
│  │   Frontend   │────────▶│  Backend API │     │
│  │  (nginx)     │         │  (nodejs)    │     │
│  │  Deployment  │         │  Deployment  │     │
│  │  + Service   │         │  + Service   │     │
│  └──────────────┘         └──────┬───────┘     │
│                                   │              │
│                                   ▼              │
│                          ┌──────────────┐       │
│                          │   Database   │       │
│                          │   (postgres) │       │
│                          │  StatefulSet │       │
│                          │  + Service   │       │
│                          └──────────────┘       │
│                                                  │
│  ConfigMaps: app-config                         │
│  Secrets: db-credentials                        │
│  NetworkPolicies: backend-only, db-only         │
└─────────────────────────────────────────────────┘
```

---

## Components

### 1. Frontend Service
- **Image:** nginx:1.27
- **Replicas:** 2-3
- **Service Type:** LoadBalancer/NodePort
- **ConfigMap:** Environment-specific configs
- **Probes:** Liveness + Readiness

### 2. Backend API Service
- **Image:** [Your API image]
- **Replicas:** 2-3 with HPA
- **Service Type:** ClusterIP
- **Secret:** Database credentials
- **NetworkPolicy:** Only accept from frontend

### 3. Database
- **Image:** postgres:15
- **Type:** StatefulSet
- **Storage:** PersistentVolume
- **Secret:** DB passwords
- **NetworkPolicy:** Only accept from backend

---

## Setup Instructions

### Prerequisites
```bash
minikube start --cpus=4 --memory=8192
minikube addons enable ingress
minikube addons enable metrics-server
```

### Deploy
```bash
# Create namespace
kubectl create namespace mini-platform

# Apply configurations
kubectl apply -f configmaps/ -n mini-platform
kubectl apply -f secrets/ -n mini-platform

# Deploy services
kubectl apply -f database/ -n mini-platform
kubectl apply -f backend/ -n mini-platform
kubectl apply -f frontend/ -n mini-platform

# Apply network policies
kubectl apply -f network-policies/ -n mini-platform
```

### Verify
```bash
kubectl get all -n mini-platform
kubectl get pv,pvc -n mini-platform
kubectl get networkpolicies -n mini-platform
```

---

## Testing

### Access Frontend
```bash
minikube service frontend-service -n mini-platform
```

### Test Backend API
```bash
kubectl port-forward -n mini-platform svc/backend-service 8080:8080
curl http://localhost:8080/api/health
```

### Check Database Connection
```bash
kubectl exec -it -n mini-platform <backend-pod> -- curl localhost:8080/api/db-check
```

---

## Lab Files Structure

```
lab/
├── README.md (this file)
├── configmaps/
│   └── app-config.yaml
├── secrets/
│   └── db-credentials.yaml
├── database/
│   ├── statefulset.yaml
│   ├── service.yaml
│   └── pvc.yaml
├── backend/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── hpa.yaml
├── frontend/
│   ├── deployment.yaml
│   └── service.yaml
└── network-policies/
    ├── backend-policy.yaml
    └── database-policy.yaml
```

---

## Show & Tell Checklist

- [ ] Demo frontend access
- [ ] Show backend API endpoints
- [ ] Verify database connectivity
- [ ] Test self-healing (delete pod)
- [ ] Test scaling (load test)
- [ ] Show network policies in action
- [ ] Explain architecture decisions

---

## Challenges & Solutions

### Challenge 1: [Add challenge]
**Solution:** [Add solution]

### Challenge 2: [Add challenge]
**Solution:** [Add solution]

---

## Improvements & Next Steps

- [ ] Add monitoring (Prometheus + Grafana)
- [ ] Implement GitOps with ArgoCD
- [ ] Add Ingress for external access
- [ ] Implement secrets management with Sealed Secrets
- [ ] Add logging with EFK stack

---

## Screenshots

[Add screenshots of your working platform]

---

**Last Updated:** 04/06/2026
