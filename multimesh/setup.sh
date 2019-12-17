#!/bin/bash
set -euo pipefail
clear

read -p "Docker Email: " username
read -sp "Docker Password: " password
echo ""
read -p "Enter a unique name for your mesh (e.g. my-super-cool-mesh): " meshid

export MESH_ID=$meshid
export DOCKER_USER=$username
export DOCKER_PASSWORD=$Password

echo ""

envsubst < cluster-mesh-2.template > cluster-mesh-2.json
envsubst < shared-rule-mesh-2.template > shared-rule-mesh-2.json

echo "🐳 Starting Minikube..."
sudo minikube config set WantUpdateNotification false # avoids issue when sourcing `minikube ip` from .profile
sudo minikube start --memory 6144 --cpus 4 --vm-driver=none &>/dev/null

# Dependencies
echo "⬇️  Downloading the Greymatter cli..."

curl -s -u $DOCKER_USER:$DOCKER_PASSWORD https://nexus.production.deciphernow.com/repository/raw-hosted/greymatter/gm-cli/greymatter-v1.0.2.tar.gz --output greymatter-v1.0.2.tar.gz
tar -xzf greymatter-v1.0.2.tar.gz
mv greymatter.linux greymatter
sudo mv greymatter /usr/local/bin
source .profile

echo "⛵ Installing Voyager Ingress..."
curl -sSL https://raw.githubusercontent.com/appscode/voyager/10.0.0/hack/deploy/voyager.sh | bash -s -- --provider=minikube &>/dev/null

# Installation
echo "🚀 Installing Grey Matter..."
kubectl create secret docker-registry docker.secret --docker-server="docker.production.deciphernow.com" --docker-username=$DOCKER_USER --docker-password=$DOCKER_PASSWORD --docker-email=$DOCKER_USER &>/dev/null
kubectl apply -f template.yaml &>/dev/null

while [[ $(kubectl get pods --field-selector=status.phase=Running --output json | jq -j '.items | length') != "8" ]]; do
    clear
    echo "✨ Waiting for pods ($(kubectl get pods --field-selector=status.phase=Running --output json | jq -j '.items | length')/8)"
    kubectl get pods | grep Running || true
    sleep 10
done

kubectl set env deployment/ping-pong MESH_ID=$MESH_ID &>/dev/null

sudo minikube service voyager-edge  &>/dev/null

echo ""

echo "The mesh is ready at https://$PUBLIC_IP:30000"