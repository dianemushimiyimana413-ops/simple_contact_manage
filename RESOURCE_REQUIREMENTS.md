# Resource Requirements & Capacity Planning

## CPU & Memory Specifications

### Per-Pod Resource Allocation

#### Request (Guaranteed - used for scheduling)
```
CPU:    100m  (0.1 cores)  - Baseline for Node.js app
Memory: 128Mi              - Minimum viable memory
```

**Justification:**
- Node.js baseline: ~50-80 MB
- Express + middleware: ~20-30 MB
- Database connection pool: ~10-20 MB
- Buffers & overhead: ~10-20 MB
- **Total: ~128 MB minimum**

#### Limit (Maximum - hard cap)
```
CPU:    500m  (0.5 cores)   - Handle peak traffic
Memory: 512Mi               - With caching & buffers
```

**Justification:**
- Peak traffic scenario: 5x baseline
- Cache storage: ~100-200 MB
- Response buffering: ~50-100 MB
- Temporary data structures: ~20-50 MB
- **Total: ~512 MB under stress**

---

## Deployment Scenarios

### Development (Single Node)
```yaml
Replicas: 1
Per Pod:
  Request: 100m CPU / 128Mi memory
  Limit:   500m CPU / 512Mi memory

Total: 100m CPU / 128Mi memory guaranteed
       500m CPU / 512Mi memory max
```

### Staging (3 Pods)
```yaml
Replicas: 3
Per Pod: 100m CPU / 128Mi memory (request)
         500m CPU / 512Mi memory (limit)

Total Guaranteed: 300m CPU / 384Mi memory
Total Max:        1500m CPU / 1.5Gi memory
```

### Production (3-10 Pods with HPA)
```yaml
Min Replicas: 3
Max Replicas: 10

Total Guaranteed: 300m CPU / 384Mi memory (minimum)
Total Max:        1500m CPU / 1.5Gi memory (minimum)
                  5000m CPU / 5Gi memory (maximum at HPA limit)
```

---

## Cluster Sizing

### Single Node (Development)
```
Recommended Machine:
  CPU:    2 cores
  Memory: 4 GB
  Storage: 20 GB

Deployment Capacity:
  Max stable pods: 10-15 (accounting for system overhead)
  Safe concurrent replicas: 3
```

### 3-Node Cluster (Staging/Small Production)
```
Per Node:
  CPU:    4 cores
  Memory: 8 GB
  Storage: 50 GB

Cluster Total:
  CPU:    12 cores
  Memory: 24 GB
  Storage: 150 GB

Deployment Capacity:
  Max stable pods: 30-40
  Safe concurrent app replicas: 9 (3 per node)
  HPA max: 10-15 pods across cluster
```

### 5-10 Node Cluster (Large Production)
```
Per Node:
  CPU:    8 cores
  Memory: 16 GB
  Storage: 100 GB

Example 10-Node Cluster:
  CPU:    80 cores
  Memory: 160 GB
  Storage: 1 TB

Deployment Capacity:
  Max stable pods: 100+
  Safe concurrent app replicas: 30+
  HPA max: 50+ pods across cluster
  Multiple applications: Yes
```

---

## Load Testing Results

### Estimated Performance

Based on typical Node.js + Express + MySQL setup:

#### Per Pod (Single Replica)
```
Requests/sec (RPS):    500-1000 RPS
Response time (p95):   50-100ms
Memory usage:          150-250 MB (includes database connection)
CPU usage:             20-40% of 1 core (depending on query complexity)
```

#### 3-Pod Deployment
```
Requests/sec (RPS):    1500-3000 RPS
Response time (p95):   50-100ms (load balanced)
Memory total:          450-750 MB
CPU total:             60-120% (0.6-1.2 cores)
```

#### With HPA (Scaling to 10 pods)
```
Requests/sec (RPS):    5000-10000 RPS
Response time (p95):   50-100ms (maintained)
Memory total:          1.5-2.5 GB
CPU total:             2.0-4.0 cores
```

---

## ResourceQuota Configuration

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: production
spec:
  hard:
    # CPU Quota
    requests.cpu: "2"     # Sum of all requests <= 2 cores
    limits.cpu: "4"       # Sum of all limits <= 4 cores
    
    # Memory Quota
    requests.memory: "2Gi"   # Sum of all requests <= 2GB
    limits.memory: "4Gi"     # Sum of all limits <= 4GB
    
    # Object Quota
    pods: "10"            # Max 10 pods in namespace
    services.loadbalancers: "2"
    persistentvolumeclaims: "5"
```

### How It Works

1. **Request Quota**: Scheduler must find nodes with available resources to satisfy all `requests`
2. **Limit Quota**: Hard limit on total resource consumption in namespace
3. **Pod Quota**: Prevents creation of new pods if limit reached

### Example

With `requests.cpu: "2"`:
- Can create 20 pods with 100m request each
- Cannot create 21st pod
- Enforces resource sharing discipline

---

## LimitRange Configuration

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: app-limits
  namespace: production
spec:
  limits:
  - type: Container
    max:
      cpu: "1"           # No container larger than 1 core
      memory: "1Gi"      # No container larger than 1GB
    min:
      cpu: "50m"         # No container smaller than 50m
      memory: "64Mi"     # No container smaller than 64MB
    default:
      cpu: "500m"        # Default limit if not specified
      memory: "512Mi"
    defaultRequest:
      cpu: "100m"        # Default request if not specified
      memory: "128Mi"
```

---

## Monitoring & Optimization

### Check Current Usage

```bash
# Pod-level resource usage
kubectl top pods -n production

# Node-level resource usage
kubectl top nodes

# Watch real-time metrics
watch -n 2 'kubectl top pods -n production'
```

### Example Output
```
NAME                                      CPU(cores)   MEMORY(bytes)
simple-contact-manager-xyz1               145m         215Mi
simple-contact-manager-xyz2               132m         198Mi
simple-contact-manager-xyz3               128m         189Mi

NAME          STATUS   ROLES                AGE   VERSION   CPU(cores)   MEMORY(bytes)
node-1        Ready    control-plane        30d   v1.27.0   342m         2456Mi
node-2        Ready    <none>               30d   v1.27.0   298m         1834Mi
node-3        Ready    <none>               30d   v1.27.0   256m         1654Mi
```

### Optimization Guidelines

| Metric | Current | Action |
|--------|---------|--------|
| CPU usage > 80% | 400m per pod | Increase limit to 750m or scale out |
| Memory usage > 75% | 384Mi per pod | Increase limit to 768Mi or optimize code |
| Pod creation fails | Many pending | Check ResourceQuota and increase if needed |
| Slow response times | p95 > 200ms | Check database connection pool, increase replicas |

---

## Cost Estimation (Cloud Providers)

### AWS (EKS)

**Node instance**: t3.xlarge (4 CPU, 16GB RAM)
- Cost per month: ~$150

**For 3-node cluster**:
- 12 CPUs, 48GB RAM
- Monthly cost: ~$450
- Egress: ~$20-50 depending on traffic

**For 10-node cluster**:
- 40 CPUs, 160GB RAM
- Monthly cost: ~$1,500
- Egress: ~$50-200

### GCP (GKE)

**Node instance**: n1-standard-4 (4 CPU, 15GB RAM)
- Cost per month: ~$120

**For 3-node cluster**:
- Monthly cost: ~$360
- Network: ~$20-40

### Azure (AKS)

**Node instance**: Standard_D4s_v3 (4 CPU, 16GB RAM)
- Cost per month: ~$130

**For 3-node cluster**:
- Monthly cost: ~$390
- Network: ~$20-50

---

## Database Resource Requirements

### MySQL Pod (if running in cluster)

```yaml
resources:
  requests:
    cpu: 250m           # Database workload needs more CPU
    memory: 256Mi       # MySQL default buffer pool
  limits:
    cpu: 1000m          # Database is CPU intensive
    memory: 1Gi         # Larger memory for caching
```

### Storage

```yaml
persistentVolume:
  capacity: 20Gi        # For storing contacts database
```

### Scaling Recommendation

- Up to 10,000 contacts: 20GB sufficient
- 100,000 contacts: 50GB recommended
- 1M+ contacts: 100GB+ with backup strategy

---

## Checklist for Production

- [ ] CPU requests: 100m per pod minimum
- [ ] Memory requests: 128Mi per pod minimum  
- [ ] CPU limits: 500m-1000m per pod
- [ ] Memory limits: 512Mi-1Gi per pod
- [ ] ResourceQuota: Set at namespace level
- [ ] LimitRange: Set at pod/container level
- [ ] HPA: Min 3, Max 10 replicas
- [ ] Health probes: Liveness, Readiness, Startup
- [ ] Pod disruption budget: 1 minimum available
- [ ] Network policies: Ingress/Egress rules defined
- [ ] Monitoring: Prometheus/monitoring enabled
- [ ] Alerts: CPU/memory thresholds configured
- [ ] Backups: Database persistence configured
- [ ] Load testing: Baseline performance verified
- [ ] Incident response: Rollback procedures tested

---

## References

- [Kubernetes Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [HPA Metrics](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [ResourceQuota & LimitRange](https://kubernetes.io/docs/concepts/policy/resource-quotas/)
- [Metrics Server](https://github.com/kubernetes-sigs/metrics-server)
