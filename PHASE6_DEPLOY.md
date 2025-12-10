# Phase 6: Deploy - Continuous Deployment Pipeline

## 📌 Overview

This document outlines the **Phase 6: Deploy** implementation for the Simple Contact Manager application. It provides:

✅ **Continuous Deployment (CD) Pipeline** - Automated deployment to Kubernetes  
✅ **Three Deployment Strategies** - Rolling, Blue-Green, and Canary  
✅ **Resource Management** - CPU/Memory requests, limits, and quotas  
✅ **High Availability** - Auto-scaling, health checks, and pod disruption budgets  
✅ **Security** - RBAC, network policies, and pod security  
✅ **Monitoring & Observability** - Health checks, probes, and logging  

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                   GitHub Repository                         │
│                      (main branch)                          │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│              GitHub Actions CI/CD Pipeline                  │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  1. CI Jobs (from ci.yml)                            │   │
│  │     ├─ Unit Tests                                    │   │
│  │     ├─ Build & Push Docker Image                     │   │
│  │     └─ Integration Tests                             │   │
│  └──────────────────┬───────────────────────────────────┘   │
│                     │                                        │
│  ┌──────────────────▼───────────────────────────────────┐   │
│  │  2. CD Jobs (from deploy.yml)                        │   │
│  │     ├─ Setup (determine strategy)                    │   │
│  │     ├─ Deploy (rolling/blue-green/canary)            │   │
│  │     ├─ Verify & Health Checks                        │   │
│  │     ├─ Smoke Tests                                   │   │
│  │     └─ Rollback (if failure)                         │   │
│  └──────────────────┬───────────────────────────────────┘   │
│                     │                                        │
└─────────────────────┼────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│          Kubernetes Cluster (production)                    │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ Namespace: production                                │   │
│  │                                                       │   │
│  │  Deployment: contact-manager                         │   │
│  │  ├─ Replicas: 3 (min) - 10 (max with HPA)           │   │
│  │  ├─ Strategy: RollingUpdate                          │   │
│  │  ├─ CPU: 250m req / 500m limit per pod              │   │
│  │  ├─ Memory: 256Mi req / 512Mi limit per pod         │   │
│  │  └─ Health Checks: startup, readiness, liveness     │   │
│  │                                                       │   │
│  │  Service: contact-manager (LoadBalancer)            │   │
│  │  ├─ Port 80 → 3000                                  │   │
│  │  └─ Auto-assigns external IP/hostname               │   │
│  │                                                       │   │
│  │  HPA: contact-manager-hpa                           │   │
│  │  ├─ Scale trigger: CPU > 70% or Memory > 80%        │   │
│  │  └─ Max replicas: 10                                │   │
│  │                                                       │   │
│  │  PDB: contact-manager-pdb                           │   │
│  │  └─ Min available: 2 pods                           │   │
│  │                                                       │   │
│  │  NetworkPolicy: contact-manager-np                  │   │
│  │  ├─ Ingress: from ingress-nginx                     │   │
│  │  └─ Egress: to MySQL, DNS, external APIs            │   │
│  │                                                       │   │
│  │  ResourceQuota: contact-manager-quota               │   │
│  │  ├─ CPU: 5 cores requests, 10 cores limits          │   │
│  │  └─ Memory: 5 Gi requests, 10 Gi limits             │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## 📂 Project Structure

```
.
├── .github/workflows/
│   ├── ci.yml                          # CI pipeline (testing, building)
│   └── deploy.yml                      # CD pipeline (deployment)
│
├── k8s/                                # Kubernetes manifests
│   ├── base/                           # Base manifests
│   │   ├── namespace.yaml              # Production namespace
│   │   ├── deployment.yaml             # Deployment with resource limits
│   │   ├── service.yaml                # LoadBalancer service
│   │   ├── serviceaccount.yaml         # RBAC roles and permissions
│   │   ├── hpa.yaml                    # Horizontal Pod Autoscaler
│   │   ├── pdb.yaml                    # Pod Disruption Budget
│   │   ├── resourcequota.yaml          # Namespace quotas
│   │   ├── networkpolicy.yaml          # Network policies
│   │   └── kustomization.yaml          # Kustomize config
│   │
│   ├── database/
│   │   └── configmap.yaml              # Database configuration
│   │
│   ├── DEPLOYMENT.md                   # Deployment guide & strategies
│   ├── RESOURCE_REQUIREMENTS.md        # Resource calculations
│   ├── QUICKSTART.md                   # Quick start guide
│   └── PHASE6_DEPLOY.md               # This file
│
├── scripts/
│   ├── deploy-rolling.sh               # Rolling update script
│   ├── deploy-blue-green.sh            # Blue-green deployment script
│   └── deploy-canary.sh                # Canary deployment script
│
├── Dockerfile                          # Container image definition
├── docker-compose.yml                  # Local development setup
├── package.json                        # Node.js dependencies
└── README.md                           # Project documentation
```

## 🚀 Quick Start

### 1. Prerequisites

- Kubernetes cluster (1.24+) with node capacity for 3+ pods
- DockerHub account for pushing images
- kubectl configured to access your cluster
- GitHub repository with Actions enabled

### 2. Setup (5 minutes)

```bash
# 1. Create Kubernetes namespace and base resources
kubectl apply -f k8s/base/namespace.yaml

# 2. Add GitHub Secrets (Settings → Secrets and variables)
# - DOCKER_USERNAME
# - DOCKER_PASSWORD
# - KUBE_CONFIG (base64-encoded)
# - SLACK_WEBHOOK (optional)

# 3. Update kubeconfig secret
cat ~/.kube/config | base64 -w 0 > kube_config_base64.txt
# Copy the output and paste in GitHub Secrets as KUBE_CONFIG

# 4. Update database password in k8s/database/configmap.yaml
# Replace 'your-secure-password-here' with a strong password
```

### 3. Deploy (1 minute)

```bash
# Automatic deployment on push
git add .
git commit -m "feat: new feature"
git push origin main

# Or manual deployment via GitHub UI
# Actions → CD - Deploy → Run workflow → Select strategy
```

### 4. Verify

```bash
kubectl get deployment contact-manager -n production
kubectl get pods -n production -l app=contact-manager
kubectl get service contact-manager -n production
```

## 🎯 Deployment Strategies

### Rolling Update (Default)
- **Use case:** Regular deployments, gradual rollouts
- **Duration:** 2-5 minutes
- **Rollback:** Automatic on health check failure
- **Downtime:** 0 seconds
- **Resource overhead:** 1 extra pod during update

### Blue-Green Deployment
- **Use case:** Major releases, zero-downtime required
- **Duration:** 3-5 minutes
- **Rollback:** 1 kubectl command
- **Downtime:** 0 seconds
- **Resource overhead:** 2x pods during deployment

### Canary Deployment
- **Use case:** High-risk features, gradual validation
- **Duration:** 8+ minutes (stages: 25% → 50% → 75% → 100%)
- **Rollback:** Automatic on error detection
- **Downtime:** 0 seconds
- **Resource overhead:** 1 extra pod per stage

**Full details:** See `k8s/DEPLOYMENT.md`

## 📊 Resource Calculations

### Per Pod
```yaml
CPU Requests:    250m   (0.25 cores - guaranteed minimum)
CPU Limits:      500m   (0.5 cores - maximum allowed)
Memory Requests: 256Mi  (guaranteed minimum)
Memory Limits:   512Mi  (maximum allowed)
```

### Baseline Deployment (3 pods)
```
CPU:    750m requests,  1500m limits
Memory: 768Mi requests, 1536Mi limits
```

### Production Peak (10 pods with HPA)
```
CPU:    2500m requests, 5000m limits
Memory: 2.56Gi requests, 5Gi limits
```

### Required Cluster Resources
```
Minimum: 2 vCPU, 4 Gi RAM
Recommended: 4 vCPU, 8 Gi RAM
Production: 6+ vCPU, 16+ Gi RAM
```

**Full details:** See `k8s/RESOURCE_REQUIREMENTS.md`

## 🔒 Security Features

✅ **Pod Security**
- Non-root user (UID 1001)
- Read-only root filesystem
- Dropped capabilities
- Security context enforced

✅ **Network Security**
- Network policies for ingress/egress control
- Communication restricted to necessary services
- Block AWS metadata service

✅ **RBAC**
- Service accounts with minimal permissions
- Role-based access control
- Read-only access to configs

✅ **Secret Management**
- Kubernetes Secrets for sensitive data
- Can integrate with Sealed Secrets or Vault
- Database credentials never in code

## 📈 Auto-scaling

```yaml
Min Replicas:  3      (high availability)
Max Replicas:  10     (cost control)

Scale Up:      CPU > 70% or Memory > 80%
Scale Down:    After 5 minutes at < 70% CPU
```

Can scale from 3 to 10 pods automatically based on load.

## 🏥 Health Checks

```yaml
Startup Probe:    150 seconds (5s × 30 retries)
Readiness Probe:  20 seconds  (10s × 2 retries)
Liveness Probe:   60 seconds  (20s × 3 retries)
```

All configured with `/health` endpoint.

## 📋 Deployment Checklist

- [ ] Kubernetes cluster ready
- [ ] GitHub Secrets configured (DOCKER_PASSWORD, KUBE_CONFIG)
- [ ] Docker image builds and pushes successfully
- [ ] k8s manifests applied to cluster
- [ ] Service created with LoadBalancer type
- [ ] Health endpoint working (/health)
- [ ] Rolling/Blue-Green/Canary scripts tested
- [ ] Monitoring and alerts configured
- [ ] Database backups scheduled
- [ ] Documentation reviewed

## 🔄 Rollback Procedures

### Rolling Update
```bash
kubectl rollout undo deployment/contact-manager -n production
```

### Blue-Green
```bash
kubectl patch service contact-manager -n production \
  -p '{"spec":{"selector":{"deployment":"blue"}}}'
```

### Automatic
- Health check fails → automatic rollback
- Slack notification sent

## 📚 Documentation

1. **DEPLOYMENT.md** - Architecture, strategies, configuration
2. **RESOURCE_REQUIREMENTS.md** - Resource calculations, capacity planning
3. **QUICKSTART.md** - Step-by-step deployment guide

## 🛠️ Common Commands

```bash
# View deployment status
kubectl get deployment contact-manager -n production
kubectl describe deployment contact-manager -n production

# View pods
kubectl get pods -n production -l app=contact-manager -o wide

# View logs
kubectl logs -n production -l app=contact-manager -f

# View service
kubectl get service contact-manager -n production

# Check scaling
kubectl get hpa contact-manager-hpa -n production -w

# Check resource usage
kubectl top pods -n production -l app=contact-manager
```

**Full command reference:** See `k8s/QUICKSTART.md`

## 🐛 Troubleshooting

**Pod not starting?**
```bash
kubectl describe pod <pod-name> -n production
kubectl logs <pod-name> -n production
```

**Image pull failures?**
```bash
docker pull docker.io/dianemushimiyimana413/simple-contact-manager:tag
```

**Resource quota exceeded?**
```bash
kubectl describe resourcequota contact-manager-quota -n production
```

**Deployment stuck?**
```bash
kubectl rollout undo deployment/contact-manager -n production
```

**Full troubleshooting guide:** See `k8s/QUICKSTART.md`

## 🔐 Required GitHub Secrets

```
DOCKER_USERNAME  # DockerHub username
DOCKER_PASSWORD  # DockerHub access token
KUBE_CONFIG      # Base64-encoded kubeconfig
SLACK_WEBHOOK    # Slack webhook URL (optional)
```

Generate secure kubeconfig:
```bash
cat ~/.kube/config | base64 -w 0
```

## 📞 Support & Monitoring

### Monitoring Tools
- Prometheus: Metrics collection
- Grafana: Visualization
- ELK Stack: Log aggregation
- Datadog/New Relic: APM

### Key Metrics
- Pod CPU/Memory utilization
- Request latency (p50, p95, p99)
- Error rate (4xx, 5xx responses)
- HPA scaling events
- Pod restart count

### Alerting
- High error rate (> 5%)
- High latency (> 1000ms)
- Pod OOMKilled
- HPA at max replicas
- ResourceQuota exceeded

## 🎓 Next Steps

1. **Read deployment guides:** `k8s/DEPLOYMENT.md`
2. **Review resource requirements:** `k8s/RESOURCE_REQUIREMENTS.md`
3. **Follow quick start:** `k8s/QUICKSTART.md`
4. **Configure monitoring:** Set up Prometheus/Grafana
5. **Test deployments:** Try rolling/blue-green/canary
6. **Setup alerts:** Configure PagerDuty/OpsGenie

## 📖 Additional Resources

- [Kubernetes Docs](https://kubernetes.io/docs/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Deployment Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [HPA Documentation](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)

---

**Phase 6 Status:** ✅ Complete

**Components Delivered:**
- ✅ CD Pipeline (.github/workflows/deploy.yml)
- ✅ Kubernetes Manifests (k8s/base/)
- ✅ Deployment Scripts (scripts/)
- ✅ Resource Definitions (CPU, Memory)
- ✅ Auto-scaling Configuration (HPA)
- ✅ Rolling/Blue-Green/Canary Strategies
- ✅ Documentation (DEPLOYMENT.md, QUICKSTART.md, RESOURCE_REQUIREMENTS.md)
