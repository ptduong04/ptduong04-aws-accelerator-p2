#!/bin/bash
set -e

# Logging
exec > >(tee /var/log/userdata.log)
exec 2>&1

echo "========================================="
echo "Starting XBrain K8s Challenge Setup"
echo "Time: $(date)"
echo "========================================="

# Update system
echo "[1/7] Updating system packages..."
apt-get update -y
apt-get upgrade -y

# Install dependencies
echo "[2/7] Installing dependencies..."
apt-get install -y \
    curl \
    wget \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    conntrack

# Install Docker
echo "[3/7] Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu
systemctl enable docker
systemctl start docker

# Install kubectl
echo "[4/7] Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# Install minikube
echo "[5/7] Installing minikube..."
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64

# Start minikube as ubuntu user
echo "[6/7] Starting minikube cluster..."
su - ubuntu -c 'minikube start --driver=docker --cpus=2 --memory=2048 --ports=30080:30080'

# Wait for cluster to be ready
su - ubuntu -c 'kubectl wait --for=condition=Ready nodes --all --timeout=300s'

# Deploy app files
echo "[7/7] Creating and deploying app..."

# Create HTML page with new orange design
cat > /home/ubuntu/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>XBrain & AWS Accelerator</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #F27830 0%, #D95323 100%);
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            color: #333;
        }
        
        .header {
            background: rgba(255, 255, 255, 0.95);
            padding: 30px 40px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.1);
        }
        
        .logo-section {
            display: flex;
            align-items: center;
            gap: 20px;
            margin-bottom: 15px;
        }
        
        .logo {
            font-size: 3rem;
            font-weight: 900;
            color: #F27830;
            letter-spacing: -2px;
        }
        
        .logo-x {
            color: #F2913D;
            font-size: 3.5rem;
        }
        
        .divider {
            width: 3px;
            height: 50px;
            background: #F2B885;
        }
        
        .program-badge {
            background: #F2913D;
            color: white;
            padding: 6px 14px;
            border-radius: 6px;
            font-size: 0.75rem;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        
        .title {
            font-size: 1.8rem;
            font-weight: 300;
            color: #333;
            margin-bottom: 8px;
        }
        
        .title strong {
            font-weight: 700;
            color: #D95323;
        }
        
        .tagline {
            color: #F27830;
            font-size: 0.9rem;
            letter-spacing: 3px;
            text-transform: uppercase;
            font-weight: 600;
        }
        
        .main-content {
            flex: 1;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 40px 20px;
        }
        
        .cards-container {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 30px;
            max-width: 1200px;
            width: 100%;
        }
        
        .card {
            background: white;
            border-radius: 16px;
            padding: 35px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.15);
            transition: transform 0.3s ease, box-shadow 0.3s ease;
        }
        
        .card:hover {
            transform: translateY(-5px);
            box-shadow: 0 15px 50px rgba(0,0,0,0.25);
        }
        
        .card-header {
            display: flex;
            align-items: center;
            gap: 15px;
            margin-bottom: 25px;
            padding-bottom: 20px;
            border-bottom: 3px solid #F2B885;
        }
        
        .card-icon {
            font-size: 3rem;
        }
        
        .card-title {
            font-size: 1.4rem;
            font-weight: 700;
            color: #D95323;
        }
        
        .info-grid {
            display: flex;
            flex-direction: column;
            gap: 18px;
        }
        
        .info-row {
            display: flex;
            flex-direction: column;
            gap: 8px;
        }
        
        .info-label {
            font-size: 0.85rem;
            color: #666;
            text-transform: uppercase;
            letter-spacing: 1px;
            font-weight: 600;
        }
        
        .info-value {
            font-size: 1.1rem;
            color: #333;
            font-weight: 500;
            padding: 10px 15px;
            background: #FFF5ED;
            border-radius: 8px;
            border-left: 4px solid #F2913D;
        }
        
        #clock {
            font-size: 1.8rem;
            font-weight: 700;
            color: #F27830;
            font-family: 'Courier New', monospace;
        }
        
        .tech-grid {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 12px;
        }
        
        .tech-item {
            background: linear-gradient(135deg, #F2913D, #F27830);
            color: white;
            padding: 12px;
            border-radius: 10px;
            text-align: center;
            font-weight: 600;
            font-size: 0.9rem;
            box-shadow: 0 4px 15px rgba(242, 120, 48, 0.3);
        }
        
        .footer {
            background: rgba(0, 0, 0, 0.8);
            color: white;
            padding: 20px 40px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .footer-left {
            display: flex;
            align-items: center;
            gap: 15px;
        }
        
        .footer-logo {
            width: 40px;
            height: 40px;
            background: #F2913D;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: 900;
            font-size: 1.2rem;
            color: white;
        }
        
        .footer-text {
            font-size: 0.85rem;
            color: #F2B885;
        }
        
        .footer-clock {
            text-align: right;
        }
        
        .footer-date {
            font-size: 0.75rem;
            color: #F2B885;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        
        .footer-time {
            font-size: 1.4rem;
            font-weight: 700;
            color: white;
            font-family: 'Courier New', monospace;
        }
        
        @media (max-width: 768px) {
            .cards-container {
                grid-template-columns: 1fr;
            }
            
            .footer {
                flex-direction: column;
                gap: 15px;
                text-align: center;
            }
            
            .tech-grid {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>
    <div class="header">
        <div class="logo-section">
            <div class="logo"><span class="logo-x">X</span>brain</div>
            <div class="divider"></div>
            <div class="program-badge">AWS Accelerator</div>
        </div>
        <h1 class="title"><strong>Xbrain</strong> & AWS Accelerator<br>& Internship Program</h1>
        <p class="tagline">— WE ARE XBUILDERS —</p>
    </div>
    
    <div class="main-content">
        <div class="cards-container">
            <div class="card">
                <div class="card-header">
                    <div class="card-icon">📊</div>
                    <div class="card-title">System Info</div>
                </div>
                <div class="info-grid">
                    <div class="info-row">
                        <div class="info-label">Current Time</div>
                        <div class="info-value" id="clock">Loading...</div>
                    </div>
                    <div class="info-row">
                        <div class="info-label">Hostname</div>
                        <div class="info-value" id="hostname">Loading...</div>
                    </div>
                    <div class="info-row">
                        <div class="info-label">Student</div>
                        <div class="info-value">ptduong04</div>
                    </div>
                </div>
            </div>
            
            <div class="card">
                <div class="card-header">
                    <div class="card-icon">🛠️</div>
                    <div class="card-title">Tech Stack</div>
                </div>
                <div class="tech-grid">
                    <div class="tech-item">🏗️ Terraform</div>
                    <div class="tech-item">☸️ Kubernetes</div>
                    <div class="tech-item">🐳 Docker</div>
                    <div class="tech-item">⚡ minikube</div>
                    <div class="tech-item">☁️ AWS EC2</div>
                    <div class="tech-item">🔀 ALB</div>
                </div>
            </div>
        </div>
    </div>
    
    <div class="footer">
        <div class="footer-left">
            <div class="footer-logo">X</div>
            <div class="footer-text">POWERED BY XBRAIN & AWS</div>
        </div>
        <div class="footer-clock">
            <div class="footer-date" id="footer-date">Loading...</div>
            <div class="footer-time" id="footer-time">Loading...</div>
        </div>
    </div>

    <script>
        function updateClock() {
            const now = new Date();
            
            const clockOptions = { 
                timeZone: 'Asia/Ho_Chi_Minh',
                year: 'numeric',
                month: '2-digit',
                day: '2-digit',
                hour: '2-digit',
                minute: '2-digit',
                second: '2-digit',
                hour12: false
            };
            document.getElementById('clock').textContent = 
                now.toLocaleString('vi-VN', clockOptions);
            
            const dateOptions = {
                timeZone: 'Asia/Ho_Chi_Minh',
                weekday: 'long',
                year: 'numeric',
                month: 'long',
                day: 'numeric'
            };
            document.getElementById('footer-date').textContent = 
                now.toLocaleString('en-US', dateOptions).toUpperCase();
            
            const timeOptions = {
                timeZone: 'Asia/Ho_Chi_Minh',
                hour: '2-digit',
                minute: '2-digit',
                second: '2-digit',
                hour12: false
            };
            document.getElementById('footer-time').textContent = 
                now.toLocaleTimeString('en-US', timeOptions);
        }
        
        document.getElementById('hostname').textContent = window.location.hostname;
        
        updateClock();
        setInterval(updateClock, 1000);
    </script>
</body>
</html>
HTMLEOF

chown ubuntu:ubuntu /home/ubuntu/index.html

# Create Dockerfile
cat > /home/ubuntu/Dockerfile << 'DOCKEREOF'
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
DOCKEREOF

chown ubuntu:ubuntu /home/ubuntu/Dockerfile

# Create K8s manifests
cat > /home/ubuntu/k8s-app.yaml << 'K8SEOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: xbrain-app
  labels:
    app: xbrain
spec:
  replicas: 2
  selector:
    matchLabels:
      app: xbrain
  template:
    metadata:
      labels:
        app: xbrain
    spec:
      containers:
      - name: nginx
        image: xbrain-app:latest
        imagePullPolicy: Never
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: xbrain-service
  labels:
    app: xbrain
spec:
  type: NodePort
  selector:
    app: xbrain
  ports:
  - port: 80
    targetPort: 80
    nodePort: ${K8S_APP_PORT}
    protocol: TCP
    name: http
K8SEOF

chown ubuntu:ubuntu /home/ubuntu/k8s-app.yaml

# Build Docker image and deploy
echo "Building Docker image..."
su - ubuntu -c 'cd ~ && docker build -t xbrain-app:latest .'

echo "Loading image into minikube..."
su - ubuntu -c 'minikube image load xbrain-app:latest'

echo "Deploying to Kubernetes..."
su - ubuntu -c 'kubectl apply -f ~/k8s-app.yaml'

echo "Waiting for deployment to be ready..."
su - ubuntu -c 'kubectl wait --for=condition=available --timeout=300s deployment/xbrain-app'

# ============================================
# CRITICAL FIX: Setup port forwarding from minikube to host
# ============================================
echo "Setting up port forwarding service..."

# Create systemd service for port forwarding
cat > /etc/systemd/system/k8s-port-forward.service << 'SERVICEEOF'
[Unit]
Description=Kubernetes Port Forward Service
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=ubuntu
Environment="HOME=/home/ubuntu"
ExecStart=/usr/local/bin/kubectl port-forward --address=0.0.0.0 service/xbrain-service ${K8S_APP_PORT}:80
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICEEOF

# Reload systemd and enable service
systemctl daemon-reload
systemctl enable k8s-port-forward.service
systemctl start k8s-port-forward.service

# Wait for port to be listening
echo "Waiting for port ${K8S_APP_PORT} to be available..."
max_wait=60
elapsed=0
while ! netstat -tuln | grep -q ":${K8S_APP_PORT}"; do
    if [ $elapsed -ge $max_wait ]; then
        echo "WARNING: Port ${K8S_APP_PORT} did not become available within $max_wait seconds"
        break
    fi
    sleep 2
    elapsed=$((elapsed + 2))
done

echo "Port forwarding service status:"
systemctl status k8s-port-forward.service --no-pager

echo "========================================="
echo "Setup completed successfully!"
echo "Time: $(date)"
echo "========================================="
echo ""
echo "Cluster Status:"
su - ubuntu -c 'kubectl get nodes'
echo ""
echo "Pods:"
su - ubuntu -c 'kubectl get pods'
echo ""
echo "Services:"
su - ubuntu -c 'kubectl get svc'
echo ""
echo "Port Forwarding Status:"
systemctl status k8s-port-forward.service --no-pager | head -10
echo ""
echo "Listening Ports:"
netstat -tuln | grep :${K8S_APP_PORT} || echo "Port ${K8S_APP_PORT} not found"
echo "========================================="
