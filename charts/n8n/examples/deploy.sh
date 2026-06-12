#!/usr/bin/env bash
# Create namespace and secrets for n8n on Oracle Cloud (OKE) / queue + multi-main.
#
# Usage:
#   ./examples/deploy.sh
#
# Override defaults via environment variables:
#   N8N_NAMESPACE=n8n \
#   N8N_HOST=n8n.example.com \
#   POSTGRES_PASSWORD='...' \
#   REDIS_PASSWORD='...' \
#   OCI_S3_SECRET_KEY='...' \
#   ./examples/deploy.sh

set -euo pipefail

NAMESPACE="${N8N_NAMESPACE:-n8n}"
N8N_HOST="${N8N_HOST:-n8n.example.com}"
N8N_PORT="${N8N_PORT:-5678}"
N8N_PROTOCOL="${N8N_PROTOCOL:-https}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-YOUR_POSTGRES_PASSWORD}"
REDIS_PASSWORD="${REDIS_PASSWORD:-YOUR_REDIS_PASSWORD}"
OCI_S3_SECRET_KEY="${OCI_S3_SECRET_KEY:-YOUR_OCI_CUSTOMER_SECRET_KEY}"

if ! command -v kubectl >/dev/null 2>&1; then
	echo "kubectl is not installed or not in PATH" >&2
	exit 1
fi

if ! kubectl cluster-info >/dev/null 2>&1; then
	echo "Cannot connect to Kubernetes cluster — configure kubectl first" >&2
	exit 1
fi

if [[ "$POSTGRES_PASSWORD" == "YOUR_POSTGRES_PASSWORD" ]] \
	|| [[ "$REDIS_PASSWORD" == "YOUR_REDIS_PASSWORD" ]] \
	|| [[ "$OCI_S3_SECRET_KEY" == "YOUR_OCI_CUSTOMER_SECRET_KEY" ]]; then
	echo "Warning: using placeholder passwords. Set POSTGRES_PASSWORD, REDIS_PASSWORD," >&2
	echo "         and OCI_S3_SECRET_KEY before running in production." >&2
	echo >&2
fi

echo "Creating namespace: ${NAMESPACE}"
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "Creating n8n-core-secrets"
kubectl create secret generic n8n-core-secrets -n "${NAMESPACE}" \
	--from-literal=N8N_ENCRYPTION_KEY="$(openssl rand -base64 32)" \
	--from-literal=N8N_HOST="${N8N_HOST}" \
	--from-literal=N8N_PORT="${N8N_PORT}" \
	--from-literal=N8N_PROTOCOL="${N8N_PROTOCOL}" \
	--dry-run=client -o yaml | kubectl apply -f -

echo "Creating n8n-db-secret"
kubectl create secret generic n8n-db-secret -n "${NAMESPACE}" \
	--from-literal=password="${POSTGRES_PASSWORD}" \
	--dry-run=client -o yaml | kubectl apply -f -

echo "Creating n8n-redis-secret"
kubectl create secret generic n8n-redis-secret -n "${NAMESPACE}" \
	--from-literal=password="${REDIS_PASSWORD}" \
	--dry-run=client -o yaml | kubectl apply -f -

echo "Creating oci-s3-credentials"
kubectl create secret generic oci-s3-credentials -n "${NAMESPACE}" \
	--from-literal=secret-access-key="${OCI_S3_SECRET_KEY}" \
	--dry-run=client -o yaml | kubectl apply -f -

echo
echo "Done. Secrets in namespace ${NAMESPACE}:"
kubectl get secrets -n "${NAMESPACE}" n8n-core-secrets n8n-db-secret n8n-redis-secret oci-s3-credentials
echo
echo "Next: customize values and install"
echo "  cp examples/multi-main-queue-oracle.yaml my-oracle-values.yaml"
echo "  helm install n8n ./charts/n8n -f my-oracle-values.yaml --namespace ${NAMESPACE}"
