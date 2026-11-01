#!/usr/bin/env bash
# Idempotently enable APIs, create a GKE Autopilot cluster and an Artifact Registry
# Docker repo. All identifiers come from the environment (direnv); nothing is hard-coded.
set -euo pipefail

: "${GCP_PROJECT_ID:?set GCP_PROJECT_ID}"
: "${GKE_LOCATION:?set GKE_LOCATION (region)}"
: "${GKE_CLUSTER_NAME:?set GKE_CLUSTER_NAME}"
: "${AR_REPO:?set AR_REPO}"

gcloud services enable container.googleapis.com artifactregistry.googleapis.com \
  --project "$GCP_PROJECT_ID"

if ! gcloud container clusters describe "$GKE_CLUSTER_NAME" \
  --location "$GKE_LOCATION" --project "$GCP_PROJECT_ID" >/dev/null 2>&1; then
  gcloud container clusters create-auto "$GKE_CLUSTER_NAME" \
    --location "$GKE_LOCATION" --project "$GCP_PROJECT_ID"
fi

if ! gcloud artifacts repositories describe "$AR_REPO" \
  --location "$GKE_LOCATION" --project "$GCP_PROJECT_ID" >/dev/null 2>&1; then
  gcloud artifacts repositories create "$AR_REPO" --repository-format docker \
    --location "$GKE_LOCATION" --project "$GCP_PROJECT_ID"
fi

gcloud container clusters get-credentials "$GKE_CLUSTER_NAME" \
  --location "$GKE_LOCATION" --project "$GCP_PROJECT_ID"
