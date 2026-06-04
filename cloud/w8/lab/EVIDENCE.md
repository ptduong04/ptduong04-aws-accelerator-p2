# W8 K8s Challenge Lab - Deployment Evidence

**Student**: ptduong04  
**Lab**: Week 8 - Kubernetes on AWS with Terraform  

---

## Live Deployment

**ALB URL**: http://xbrain-k8s-7c440e-alb-1782513482.us-west-2.elb.amazonaws.com

**Status**: **DEPLOYED & ACCESSIBLE**

---

## Evidence: Browser Screenshot

![Browser Evidence](.\asset\terraform_apply_complete.jpg)

**Screenshot shows:**
- ALB DNS name visible in URL bar
- Application running successfully
- XBrain branded interface with orange color scheme
- Real-time system information display
- Tech stack: Terraform, Kubernetes, Docker, minikube, AWS EC2, ALB

---

## Infrastructure Architecture Diagram

![Diagram Evidence](.\asset\Diagram.jpg)

**Traffic flow**: Internet User → IGW → ALB :80 → EC2 :30080 → port-forward → xbrain-service :80 → 2 Nginx Pods

**Add labels**: VPC 10.0.0.0/16, Public Subnet A/B, us-west-2a/b, EC2 t3.medium, Minikube Cluster

---

## Technology Stack

| Component | Technology | Details |
|-----------|-----------|---------|
| **IaC** | Terraform | v1.5+ with AWS + Kubernetes providers |
| **Cloud** | AWS | Region: us-west-2 |
| **Networking** | VPC + ALB | 2 AZs, Internet Gateway, Security Groups |
| **Compute** | EC2 t3.medium | Ubuntu, 20GB gp3 encrypted |
| **Container Runtime** | Docker | Latest stable |
| **Orchestration** | Kubernetes (minikube) | Single-node cluster |
| **Web Server** | Nginx | Alpine-based custom image |
| **Load Balancer** | Application LB | HTTP listener, target group |

---

## Deployment Details

### Infrastructure Resources Created:

1. **VPC Resources:**
   - VPC: `10.0.0.0/16`
   - 2 Public Subnets (Multi-AZ: us-west-2a, us-west-2b)
   - Internet Gateway
   - Route Tables

2. **Compute:**
   - EC2 Instance: `i-013290c608adf1648`
   - Instance Type: `t3.medium`
   - Public IP: `52.24.167.59`
   - Elastic IP attached

3. **Load Balancing:**
   - ALB: `xbrain-k8s-7c440e-alb`
   - Target Group: Port 30080
   - Health Check: HTTP GET / (200 OK)
   - Status: **Healthy**

4. **Security Groups:**
   - ALB SG: Allow inbound 80 from `0.0.0.0/0`
   - EC2 SG: Allow 30080 from ALB, SSH from anywhere

5. **Kubernetes Resources:**
   - Deployment: `xbrain-app` (2 replicas)
   - Service: `xbrain-service` (NodePort 30080)
   - Port Forwarding: systemd service

---

## Key Technical Solutions

### 1. Port Forwarding Challenge
**Problem**: minikube running in Docker doesn't expose NodePort to host.

**Solution**: Created systemd service with `kubectl port-forward`:
```bash
kubectl port-forward --address=0.0.0.0 service/xbrain-service 30080:80
```

### 2. Provider Requirements
**Requirement**: ≥2 different service providers

**Implementation**:
- AWS Provider (hashicorp/aws ~> 5.0)
- Kubernetes Provider (hashicorp/kubernetes ~> 2.23)
- Random provider (utility only, for unique naming)

### 3. High Availability
- Multi-AZ deployment (us-west-2a, us-west-2b)
- ALB health checks with auto-recovery
- 2 pod replicas for application redundancy

---

## Verification Results

### ALB Health Check:
```json
{
  "Target": "i-013290c608adf1648",
  "Port": 30080,
  "State": "healthy",
  "Reason": null
}
```

### HTTP Response:
```
HTTP/1.1 200 OK
Content-Type: text/html
Content-Length: 10342
```

### Application Features:
- Real-time clock (Asia/Ho_Chi_Minh timezone)
- Dynamic hostname display
- Responsive design
- XBrain branding (colors: #F2913D, #F27830, #D95323)

---

## Compliance Checklist

- Terraform code với ≥2 provider khác nhau (AWS + Kubernetes)
- Triển khai app lên K8s (minikube) trên EC2
- App accessible qua ALB URL
- Browser screenshot evidence
- Architecture diagram
- Clean, documented code

---

## Quick Deploy Commands

```bash
# Deploy
cd d:\Cloud\cloud\w8\lab\terraform
terraform init
terraform apply -auto-approve

# Destroy
terraform destroy -auto-approve
```

---

**Deployment Date**: June 4, 2026  
**Status**: **PRODUCTION READY**  
**Evidence Collected By**: ptduong04
