# k8s manifests for simple-contact-manager

Per-replica sizing chosen as baseline:
- CPU request: 250m (0.25 vCPU)
- Memory request: 256Mi
- CPU limit: 500m
- Memory limit: 512Mi

Replicas: 3

Totals:
- CPU requested total = 0.25 * 3 = 0.75 vCPU (750m)
- Memory requested total = 256Mi * 3 = 768Mi

With 20% headroom:
- CPU ~ 0.9 vCPU (900m)
- Memory ~ 922Mi

Notes:
- CI updates image via: kubectl -n default set image deployment/simple-contact-manager simple-contact-manager=${DOCKER_USERNAME}/simple-contact-manager:latest
- Ensure repo secrets: DOCKER_USERNAME, DOCKER_PASSWORD, KUBE_CONFIG_DATA (base64 kubeconfig)
- App must expose port 3000 and provide a /healthz endpoint or update readiness/liveness probes accordingly.
- Consider adding HorizontalPodAutoscaler and PodDisruptionBudget for production.
