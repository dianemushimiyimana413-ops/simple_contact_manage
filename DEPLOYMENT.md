# Phase 6: CD Pipeline & Deployment Strategy

This document outlines the deployment infrastructure for the Simple Contact Manager application with comprehensive CD pipeline, Kubernetes orchestration, and deployment strategies.

## Table of Contents

1. [Overview](#overview)
2. [Deployment Strategies](#deployment-strategies)
3. [Kubernetes Configuration](#kubernetes-configuration)
4. [Resource Requirements](#resource-requirements)
5. [CD Pipeline](#cd-pipeline)
6. [Setup Instructions](#setup-instructions)
7. [Monitoring & Rollback](#monitoring--rollback)

---

## Overview

The deployment architecture supports:
- **Multiple environments**: Development, staging, and production
- **Zero-downtime deployments**: Rolling updates and blue-green strategies
- **Auto-scaling**: Horizontal Pod Autoscaling based on CPU/memory
- **High availability**: Multi-replica deployments with health checks
- **Security**: Network policies, RBAC, and resource limits
- **Observability**: Health checks, logging, and metrics

---

## Deployment Strategies

### 1. Rolling Update (Default)

Gradually replaces old pods with new ones, ensuring service availability.

**Configuration:**
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1          # 1 extra pod during update
    maxUnavailable: 0    # Zero downtime
```

**Process:**
1. New pod with updated image starts
2. Health checks verify readiness
3. Traffic gradually shifts to new pod
4. Old pod terminates

**Advantages:**
- Simple, automatic rollback
- Minimal resource overhead
- Good for most use cases

**Rollout Status:**
```bash
kubectl rollout status deployment/simple-contact-manager -n production
kubectl rollout undo deployment/simple-contact-manager -n production
```

### 2. Blue-Green Deployment

Maintains two identical production environments. Traffic switches instantly between them.

**Process:**
1. Deploy new version to inactive environment (green)
2. Run smoke tests on green
3. Switch traffic from blue to green
4. Keep blue running for instant rollback

**Advantages:**
- True zero-downtime deployment
- Instant rollback capability
- Full environment validation before traffic switch

**Usage:**
```bash
chmod +x scripts/blue-green-deploy.sh
./scripts/blue-green-deploy.sh v1.2.0

# Rollback
./scripts/blue-green-rollback.sh
```

**File:** `.github/workflows/deploy.yml` with `deployment_strategy: blue-green`

---

## Kubernetes Configuration

### Deployment Manifest (`k8s/deployment.yaml`)

**Key Features:**

#### Replicas & Strategy
```yaml
replicas: 3                    # High availability with 3 pods
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1               # Never exceed 4 pods
    maxUnavailable: 0         # Always available
```

#### Health Checks

**Liveness Probe** (Container restart trigger):
- HTTP GET `/api/health`
- Check every 10s
- Fail after 3 consecutive failures

**Readiness Probe** (Load balancer traffic control):
- HTTP GET `/api/health`
- Check every 5s
- Remove from load balancer after 2 failures

**Startup Probe** (Boot-up grace period):
- HTTP GET `/api/health`
- Give up to 2.5 minutes for app to start

#### Resource Requests & Limits

**Per Pod:**
```yaml
requests:          # Guaranteed resources (used for scheduling)
  cpu: 100m        # 0.1 CPU cores
  memory: 128Mi    # 128 MiB RAM

limits:            # Maximum allowed usage
  cpu: 500m        # 0.5 CPU cores
  memory: 512Mi    # 512 MiB RAM
```

**Cluster-wide (ResourceQuota):**
```yaml
requests.cpu: 2     # Total 2 CPU cores
requests.memory: 2Gi
limits.cpu: 4       # Total 4 CPU cores
limits.memory: 4Gi
pods: 10            # Max 10 pods
```

#### Security

```yaml
securityContext:
  runAsNonRoot: true          # No root access
  runAsUser: 1001             # Specific user ID
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: [ALL]               # Drop all capabilities
```

#### Pod Affinity

Spreads pods across different nodes for better availability:
```yaml
podAntiAffinity:
  preferredDuringScheduling:
    - topology: kubernetes.io/hostname  # Prefer different nodes
```

### Service (`k8s/service.yaml`)

- **Type**: LoadBalancer (integrates with cloud provider)
- **Selector**: Routes to pods with label `app: simple-contact-manager`
- **Port mapping**: 80 → 3000

### ConfigMap (`k8s/configmap.yaml`)

Non-sensitive configuration:
- Database host, port, name
- Logging level
- Application settings

### Secrets (`k8s/configmap.yaml` - Secret section)

Sensitive data:
- Database password
- API keys (if any)

**Inject from CI/CD:**
```bash
kubectl create secret generic app-secrets \
  --from-literal=db-password=<actual-password> \
  -n production
```

---

## Resource Requirements

### CPU & Memory Calculations

**Per Pod Baseline:**
- Node.js runtime: ~50-80 MB
- Express framework: ~20-30 MB
- Database connection pool: ~20-40 MB
- Application code: ~10-20 MB
- **Total minimum: ~128 MB**

**Peak Usage (with caching):**
- Active connections: varies
- Middleware overhead: ~30 MB
- Cache storage: ~100-200 MB
- **Total max: ~512 MB**

**CPU Usage:**
- Idle state: 5-10% of 1 core
- Normal traffic: 20-30% of 1 core
- Peak traffic: 60-80% of 1 core

### Recommended Configuration

```yaml
Per Pod:
  Request CPU:  100m   (room for 10 pods per core)
  Request Mem:  128Mi  (baseline + overhead)
  Limit CPU:    500m   (handle 5x normal traffic)
  Limit Mem:    512Mi  (with caching & buffers)

For 3 Replicas:
  Requested: 300m CPU, 384Mi memory
  Limited:   1500m CPU, 1.5Gi memory

For 10 Node Cluster:
  Total Requested: 3 CPUs, 3.8 Gi
  Total Limited:   15 CPUs, 15 Gi
```

### Horizontal Pod Autoscaler (HPA)

```yaml
minReplicas: 3          # Always keep 3 pods
maxReplicas: 10         # Never exceed 10 pods
scaleUp:    100% (double) every 30s
scaleDown:  50% when calm for 5 minutes
```

**Triggers:**
- CPU > 70% → scale up
- Memory > 80% → scale up
- Both metrics must be healthy to scale down

---

## CD Pipeline

### Workflow Trigger

The `.github/workflows/deploy.yml` workflow triggers on:
- Push to `main` branch
- Tag push (`v*`)
- Manual dispatch

### Pipeline Stages

#### 1. Build & Test (from CI pipeline)
- Run unit tests
- Build Docker image
- Push to registry

#### 2. Deploy
Choose strategy via `deployment_strategy` input:

**Rolling Update (default):**
```bash
kubectl set image deployment/simple-contact-manager \
  app=<registry>/<image>:<tag> \
  -n production \
  --record

kubectl rollout status deployment/simple-contact-manager \
  -n production \
  --timeout=5m
```

**Blue-Green:**
```bash
./scripts/blue-green-deploy.sh <tag>
```

#### 3. Smoke Tests
```bash
curl http://$SERVICE_IP:3000/api/health
```

#### 4. Rollback (on failure)
```bash
kubectl rollout undo deployment/simple-contact-manager -n production
```

### Environment Variables

```yaml
REGISTRY: docker.io
IMAGE_NAME: ${{ secrets.DOCKER_USERNAME }}/simple_contact_manager
KUBE_CLUSTER: ${{ secrets.KUBE_CLUSTER }}
KUBE_NAMESPACE: production
```

### Required GitHub Secrets

```
DOCKER_USERNAME      - DockerHub username
DOCKER_PASSWORD      - DockerHub token
KUBE_CONFIG         - Base64 encoded kubeconfig
KUBE_CLUSTER        - Cluster name/endpoint (optional)
```

---

## Setup Instructions

### Prerequisites

1. **Kubernetes Cluster**
   ```bash
   # Kind (local)
   kind create cluster --name contact-manager
   
   # Minikube
   minikube start --cpus 4 --memory 8192
   
   # Cloud: GKE, EKS, AKS
   gcloud container clusters create contact-manager --num-nodes 3
   ```

2. **kubectl**
   ```bash
   kubectl version --client
   ```

3. **Docker Registry Access**
   - DockerHub account or private registry

### Step 1: Initialize Cluster

```bash
# Make script executable
chmod +x scripts/k8s-init.sh

# Run initialization
DOCKER_USERNAME=<username> \
DOCKER_PASSWORD=<token> \
DB_PASSWORD=<secure-password> \
./scripts/k8s-init.sh
```

This creates:
- `production` namespace
- Secrets and ConfigMaps
- ResourceQuota and LimitRange
- NetworkPolicy
- Initial deployment

### Step 2: Configure GitHub Secrets

```bash
# Generate base64 kubeconfig
cat ~/.kube/config | base64 | pbcopy

# Add to GitHub repository:
# Settings → Secrets → New repository secret
# KUBE_CONFIG = <base64 content>
# DOCKER_USERNAME = <username>
# DOCKER_PASSWORD = <token>
```

### Step 3: Deploy

```bash
# Manual trigger
git push origin main

# Or use GitHub Actions UI to trigger deploy.yml manually
# Select deployment_strategy: rolling or blue-green
```

### Step 4: Verify Deployment

```bash
# Check pods
kubectl get pods -n production

# Check deployment status
kubectl rollout status deployment/simple-contact-manager -n production

# Check service
kubectl get service simple-contact-manager -n production

# Port forward to test locally
kubectl port-forward svc/simple-contact-manager 3000:80 -n production
curl http://localhost:3000/api/health
```

---

## Monitoring & Rollback

### View Deployment Logs

```bash
# Last 100 lines
kubectl logs -n production -l app=simple-contact-manager --tail=100

# Real-time streaming
kubectl logs -n production -l app=simple-contact-manager -f

# Specific pod
kubectl logs -n production <pod-name>
```

### Monitor Resources

```bash
# Pod resource usage
kubectl top pods -n production

# Node resource usage
kubectl top nodes

# Watch metrics
watch -n 2 'kubectl top pods -n production'
```

### View Events

```bash
kubectl get events -n production --sort-by='.lastTimestamp'
```

### Rollback Deployment

```bash
# See rollout history
kubectl rollout history deployment/simple-contact-manager -n production

# Rollback to previous version
kubectl rollout undo deployment/simple-contact-manager -n production

# Rollback to specific revision
kubectl rollout undo deployment/simple-contact-manager -n production --to-revision=2

# Check status
kubectl rollout status deployment/simple-contact-manager -n production
```

### Blue-Green Rollback

```bash
# If automated rollback fails
./scripts/blue-green-rollback.sh

# Manual switch back to previous version
kubectl patch service simple-contact-manager -n production \
  -p '{"spec":{"selector":{"deployment":"blue"}}}'
```

### Debugging

```bash
# Get pod details
kubectl describe pod <pod-name> -n production

# Get deployment details
kubectl describe deployment simple-contact-manager -n production

# Get service details
kubectl describe service simple-contact-manager -n production

# Check probes
kubectl get pods -n production -o jsonpath='{.items[*].status.conditions}' | jq

# Debug with shell
kubectl exec -it <pod-name> -n production -- /bin/sh
```

---

## Docker Swarm Alternative

For those preferring Docker Swarm over Kubernetes:

```bash
# Initialize Swarm (on manager node)
docker swarm init

# Deploy service
chmod +x scripts/swarm-deploy.sh
./scripts/swarm-deploy.sh dianemushimiyimana413/simple_contact_manager:latest 3

# View services
docker service ls
docker service ps simple-contact-manager

# Update service
docker service update \
  --image dianemushimiyimana413/simple_contact_manager:v1.2.0 \
  simple-contact-manager

# Rollback
docker service rollback simple-contact-manager
```

**Docker Swarm Resource Limits:**
```
--limit-cpu=0.5          # CPU cap
--limit-memory=512m      # Memory cap
--reserve-cpu=0.1        # Guaranteed CPU
--reserve-memory=128m    # Guaranteed memory
```

---

## Summary

This Phase 6 implementation provides:

✅ **Two deployment strategies**: Rolling (default) and Blue-Green  
✅ **Kubernetes orchestration**: Auto-scaling, health checks, security  
✅ **Resource management**: Quotas, limits, and calculated requirements  
✅ **CI/CD integration**: Automated deployment pipeline  
✅ **High availability**: Multi-replica deployments  
✅ **Zero-downtime updates**: Graceful transitions  
✅ **Easy rollback**: One-command recovery  
✅ **Docker Swarm alternative**: For simpler orchestration  

For questions or customization, refer to the official documentation:
- [Kubernetes Docs](https://kubernetes.io/docs/)
- [Docker Swarm Docs](https://docs.docker.com/engine/swarm/)
