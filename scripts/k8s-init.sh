#!/bin/bash

# Kubernetes Deployment Initialization Script
# Sets up namespaces, secrets, and initial deployments

set -e

NAMESPACE="production"
REGISTRY="docker.io"
DOCKER_USERNAME="${DOCKER_USERNAME:-dianemushimiyimana413}"
DOCKER_PASSWORD="${DOCKER_PASSWORD:-}"
DB_PASSWORD="${DB_PASSWORD:-password}"

echo "🔧 Initializing Kubernetes Cluster"

# Create namespace if it doesn't exist
echo "📁 Creating namespace: $NAMESPACE"
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Label namespace for network policies
kubectl label namespace $NAMESPACE name=$NAMESPACE --overwrite

# Create Docker registry secret if credentials provided
if [ -n "$DOCKER_PASSWORD" ]; then
    echo "🔐 Creating Docker registry secret..."
    kubectl create secret docker-registry dockerhub-secret \
        --docker-server=$REGISTRY \
        --docker-username=$DOCKER_USERNAME \
        --docker-password=$DOCKER_PASSWORD \
        --docker-email="$DOCKER_USERNAME@example.com" \
        -n $NAMESPACE \
        --dry-run=client -o yaml | kubectl apply -f -
fi

# Apply ConfigMaps and Secrets
echo "⚙️  Applying configuration..."
kubectl apply -f k8s/configmap.yaml

# Update secret with actual password
kubectl patch secret app-secrets -n $NAMESPACE -p "{\"data\":{\"db-password\":\"$(echo -n $DB_PASSWORD | base64)\"}}" || true

# Apply ResourceQuota and LimitRange
echo "📊 Setting resource quotas and limits..."
kubectl apply -f k8s/resource-quota.yaml

# Apply NetworkPolicy
echo "🔐 Applying network policies..."
kubectl apply -f k8s/network-policy.yaml

# Create blue deployment (initial)
echo "🔵 Creating blue deployment..."
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/deployment.yaml

# Rename deployment for blue-green strategy
kubectl patch deployment simple-contact-manager -n $NAMESPACE -p '{"metadata":{"labels":{"deployment":"blue"}}}'
kubectl patch deployment simple-contact-manager -n $NAMESPACE --type='json' -p='[{"op": "rename", "path": "/metadata/name", "value":"simple-contact-manager-blue"}]' || true

# Apply HPA
echo "📈 Setting up horizontal pod autoscaler..."
kubectl apply -f k8s/hpa.yaml

# Wait for deployment to be ready
echo "⏳ Waiting for initial deployment to be ready..."
kubectl rollout status deployment/simple-contact-manager -n $NAMESPACE --timeout=5m || kubectl rollout status deployment/simple-contact-manager-blue -n $NAMESPACE --timeout=5m

echo "✅ Kubernetes cluster initialized successfully!"
echo ""
echo "📊 Cluster Status:"
kubectl get all -n $NAMESPACE
echo ""
echo "💡 Next steps:"
echo "  1. Configure your kubeconfig with cluster access"
echo "  2. Set required GitHub secrets: KUBE_CONFIG, DOCKER_USERNAME, DOCKER_PASSWORD"
echo "  3. Push code to main branch to trigger CD pipeline"
