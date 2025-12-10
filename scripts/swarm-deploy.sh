#!/bin/bash

# Docker Swarm Deployment Script
# Alternative to Kubernetes for container orchestration

set -e

SERVICE_NAME="simple-contact-manager"
IMAGE="${1:-dianemushimiyimana413/simple_contact_manager:latest}"
REPLICAS="${2:-3}"

echo "🚀 Deploying to Docker Swarm"
echo "Service: $SERVICE_NAME"
echo "Image: $IMAGE"
echo "Replicas: $REPLICAS"

# Check if Docker Swarm is initialized
if ! docker info | grep -q "Swarm: active"; then
    echo "❌ Docker Swarm is not active. Initialize with: docker swarm init"
    exit 1
fi

# Create overlay network if it doesn't exist
docker network ls | grep -q contact-swarm || \
    docker network create --driver overlay --attachable contact-swarm

# Deploy using stack (compose-like syntax)
docker service create \
    --name $SERVICE_NAME \
    --replicas $REPLICAS \
    --publish published=80,target=3000 \
    --network contact-swarm \
    --health-cmd="node healthcheck.js" \
    --health-interval=30s \
    --health-timeout=3s \
    --health-retries=3 \
    --limit-cpu=0.5 \
    --limit-memory=512m \
    --reserve-cpu=0.1 \
    --reserve-memory=128m \
    --env "DB_HOST=mysql-service" \
    --env "DB_USER=root" \
    --env "DB_PASSWORD=password" \
    --env "DB_NAME=contacts_db" \
    --env "NODE_ENV=production" \
    $IMAGE 2>/dev/null || \
    docker service update \
        --image $IMAGE \
        --replicas $REPLICAS \
        $SERVICE_NAME

# Wait for service to stabilize
echo "⏳ Waiting for service to stabilize..."
sleep 10

# Check service status
docker service ls
docker service ps $SERVICE_NAME

echo "✅ Docker Swarm Deployment Completed!"
