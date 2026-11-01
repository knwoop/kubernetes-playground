#!/usr/bin/env bash
# Apply the manifests. Run only after the review gate is approved.
# Needs (from the environment, e.g. direnv): REGISTRY_IMAGE, CLAUDE_ORG_UUID.
# The organization UUID is substituted at apply time and is never written to the repo.
set -euo pipefail

: "${REGISTRY_IMAGE:?set REGISTRY_IMAGE (the pushed image reference)}"
: "${CLAUDE_ORG_UUID:?set CLAUDE_ORG_UUID (your Claude organization UUID; login fails without the right one)}"
[[ "$CLAUDE_ORG_UUID" =~ ^[0-9a-fA-F-]{36}$ ]] || { echo "CLAUDE_ORG_UUID does not look like a UUID" >&2; exit 2; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S="$HERE/k8s"

kubectl apply -f "$K8S/namespace.yaml"
kubectl apply -f "$K8S/serviceaccount.yaml"
sed "s/REPLACE_WITH_ORG_UUID/$CLAUDE_ORG_UUID/" "$K8S/configmap-managed-settings.yaml" | kubectl apply -f -
IMAGE="$REGISTRY_IMAGE" envsubst '${IMAGE}' < "$K8S/statefulset.yaml" | kubectl apply -f -

kubectl -n claude-agent rollout status statefulset/claude --timeout=600s
kubectl -n claude-agent get pod claude-0
