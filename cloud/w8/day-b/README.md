# Day B - K8s Container/Orchestration

**Date:** 02/06/2026 - 04/06/2026

## Learning Objectives
- Understand Kubernetes architecture
- Master Pod, Service, Deployment concepts
- Configure health checks (probes)
- Manage configuration with ConfigMap and Secret
- Implement basic NetworkPolicy

---

## Topics Covered

### 1. Container Fundamentals
- Containers vs VMs
- Docker basics
- Container images and registries

### 2. Kubernetes Architecture
- Control Plane: API Server, etcd, Scheduler, Controller Manager
- Worker Nodes: kubelet, kube-proxy, container runtime

### 3. Core Resources

#### Pod
- Smallest deployable unit
- Pod lifecycle
- Multi-container patterns

#### Service
- ClusterIP, NodePort, LoadBalancer
- Service discovery
- Endpoints

#### Deployment
- Declarative updates
- Rolling updates
- Rollback capabilities

### 4. Health Checks
- Liveness Probe: Is container alive?
- Readiness Probe: Is container ready for traffic?
- Startup Probe: For slow-starting apps

### 5. Configuration Management
- ConfigMap for non-sensitive data
- Secret for sensitive data
- Environment variables vs volume mounts

### 6. Network Security
- NetworkPolicy for pod-to-pod communication
- Ingress and Egress rules

---

## Hands-on Labs

### Lab 1: Create and Manage Pods
```bash
kubectl run hello --image=nginx:1.27 --port=80
kubectl get pods -o wide
kubectl describe pod hello
kubectl exec -it hello -- sh
kubectl delete pod hello
```

### Lab 2: Deployments
```bash
kubectl apply -f deployment.yaml
kubectl get deploy,rs,pods
kubectl scale deployment web --replicas=5
kubectl rollout status deployment/web
```

### Lab 3: ConfigMap & Secret
```bash
kubectl create configmap app-cfg --from-literal=APP_ENV=production
kubectl create secret generic app-sec --from-literal=DB_PASSWORD=s3cr3t
kubectl set env deployment/web --from=configmap/app-cfg
```

---

## Key Commands Reference

See: [KUBERNETES_COMMANDS_CHEATSHEET.md](../KUBERNETES_COMMANDS_CHEATSHEET.md)

---

## Resources
- [Kubernetes Official Docs](https://kubernetes.io/docs)
- [Kubernetes Basics Tutorial](https://kubernetes.io/docs/tutorials/kubernetes-basics)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet)

---

## Notes & Reflections

[Add your personal notes and insights here]
