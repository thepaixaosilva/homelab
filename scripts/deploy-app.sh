#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$1"
APP_NAME=$(basename "$APP_DIR")
NAMESPACE="$APP_NAME"

REPO_URL=$(yq '.repoURL' "$APP_DIR/source.yaml")
CHART=$(yq '.chart' "$APP_DIR/source.yaml")
VERSION=$(yq '.version' "$APP_DIR/source.yaml")

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

REQUIRED_SECRETS=$(yq '.requiredSecrets // [] | .[].name' "$APP_DIR/source.yaml")
for SECRET_NAME in $REQUIRED_SECRETS; do
  if ! kubectl -n "$NAMESPACE" get secret "$SECRET_NAME" >/dev/null 2>&1; then
    echo "[X] Secret '$SECRET_NAME' is missing from namespace '$NAMESPACE'."
    echo "    Create it before running this script, e.g.:"
    echo "    kubectl -n $NAMESPACE create secret generic $SECRET_NAME --from-literal=key=value"
    exit 1
  fi
done

if [[ "$REPO_URL" == oci://* ]]; then
    CHART_REF="$REPO_URL"
else
    helm repo add "{APP_NAME}-repo" "$REPO_URL" > /dev/null
    helm repo update "{APP_NAME}-repo" > /dev/null
    CHART_REF="{APP_NAME}-repo/$CHART"
fi

helm upgrade --install "$APP_NAME" "$CHART_REF" \
    --version "$VERSION" \
    --namespace "$APP_NAME" \
    --create-namespace \
    -f "$APP_DIR/values.yaml"
