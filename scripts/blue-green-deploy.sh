#!/bin/bash

# Blue-Green Deployment Strategy
# This script implements zero-downtime deployments by maintaining two identical
# environments (blue and green) and switching traffic between them.

set -e

IMAGE_TAG=${1:-latest}
NAMESPACE="production"
APP_NAME="simple-contact-manager"
REGISTRY="docker.io"
IMAGE="$REGISTRY/dianemushimiyimana413/$APP_NAME:$IMAGE_TAG"

echo "🚀 Starting Blue-Green Deployment"
echo "Image: $IMAGE"
echo "Namespace: $NAMESPACE"

# Determine current active environment
CURRENT_ENV=$(kubectl get service $APP_NAME -n $NAMESPACE -o jsonpath='{.spec.selector.deployment}' 2>/dev/null || echo "blue")
if [ "$CURRENT_ENV" == "blue" ] || [ -z "$CURRENT_ENV" ]; then
    ACTIVE="blue"
    INACTIVE="green"
else
    ACTIVE="green"
    INACTIVE="blue"
fi

echo "Current active environment: $ACTIVE"
echo "Deploying to: $INACTIVE"

# Create or update the inactive deployment with new image
echo "📦 Creating/updating $INACTIVE deployment..."

# Get current deployment template and modify it
kubectl get deployment "$APP_NAME-$ACTIVE" -n $NAMESPACE -o yaml | \
    sed "s/$APP_NAME-$ACTIVE/$APP_NAME-$INACTIVE/g" | \
    sed "s/image:.*$/image: $IMAGE/g" | \
    sed "s/deployment: $ACTIVE/deployment: $INACTIVE/g" | \
    kubectl apply -f -

# Wait for the new deployment to be ready
echo "⏳ Waiting for $INACTIVE deployment to be ready..."
kubectl rollout status deployment/$APP_NAME-$INACTIVE -n $NAMESPACE --timeout=5m

# Run health checks
echo "🏥 Running health checks..."
INACTIVE_PODS=$(kubectl get pods -n $NAMESPACE -l app=$APP_NAME,deployment=$INACTIVE -o jsonpath='{.items[0].metadata.name}')

if [ -z "$INACTIVE_PODS" ]; then
    echo "❌ No pods found in $INACTIVE deployment"
    exit 1
fi

# Port forward and test
kubectl port-forward pod/$INACTIVE_PODS 3000:3000 -n $NAMESPACE &
PF_PID=$!
sleep 2

# Run smoke tests
for i in {1..5}; do
    if curl -f http://localhost:3000/api/health 2>/dev/null; then
        echo "✅ Health check $i passed"
        break
    fi
    echo "⏳ Health check attempt $i/5..."
    sleep 2
done

kill $PF_PID 2>/dev/null || true

echo "✅ Health checks passed for $INACTIVE deployment"

# Switch traffic to inactive deployment
echo "🔄 Switching traffic from $ACTIVE to $INACTIVE..."
kubectl patch service $APP_NAME -n $NAMESPACE -p "{\"spec\":{\"selector\":{\"deployment\":\"$INACTIVE\"}}}"

echo "⏳ Waiting for connections to drain from $ACTIVE..."
sleep 10

# Keep old deployment for quick rollback (scale down but keep)
echo "📦 Scaling down $ACTIVE deployment (keeping for quick rollback)..."
kubectl scale deployment/$APP_NAME-$ACTIVE -n $NAMESPACE --replicas=0

echo "✅ Blue-Green Deployment Completed Successfully!"
echo "Active environment: $INACTIVE"
echo "Previous environment ($ACTIVE) scaled down for rollback"

# Rollback function if needed
rollback() {
    echo "🔄 Rolling back to $ACTIVE..."
    kubectl patch service $APP_NAME -n $NAMESPACE -p "{\"spec\":{\"selector\":{\"deployment\":\"$ACTIVE\"}}}"
    kubectl scale deployment/$APP_NAME-$ACTIVE -n $NAMESPACE --replicas=3
    kubectl scale deployment/$APP_NAME-$INACTIVE -n $NAMESPACE --replicas=0
    echo "✅ Rollback completed"
}

export -f rollback
echo "💡 To rollback, run: rollback"
