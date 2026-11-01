#!/usr/bin/env bash
# Build the image on Cloud Build (native amd64) and push it to REGISTRY_IMAGE.
# Identifiers come from the environment (direnv); nothing is hard-coded.
set -euo pipefail

: "${GCP_PROJECT_ID:?set GCP_PROJECT_ID}"
: "${REGISTRY_IMAGE:?set REGISTRY_IMAGE (full image reference)}"
VERSION="${CLAUDE_CODE_VERSION:-2.1.316}"
# Cloud Build workers are amd64; another platform needs a native builder (untested).
PLATFORM="${PLATFORM:-linux/amd64}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

gcloud services enable cloudbuild.googleapis.com --project "$GCP_PROJECT_ID"

gcloud builds submit "$HERE" \
  --project "$GCP_PROJECT_ID" \
  --config "$HERE/cloudbuild.yaml" \
  --substitutions "_IMAGE=$REGISTRY_IMAGE,_CLAUDE_CODE_VERSION=$VERSION,_PLATFORM=$PLATFORM"
