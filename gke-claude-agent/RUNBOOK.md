# Runbook: deploy and log in

The login is a human step. Nothing here runs `claude auth login` for you, and no API key or token is used anywhere.

Identifiers come from direnv variables, never from this repo: `GCP_PROJECT_ID`, `GKE_LOCATION`, `GKE_CLUSTER_NAME`, `REGISTRY_IMAGE`, and `CLAUDE_ORG_UUID` (your Claude organization UUID).

## 1. Deploy

```bash
gcloud container clusters get-credentials "$GKE_CLUSTER_NAME" --location "$GKE_LOCATION" --project "$GCP_PROJECT_ID"
bash gke-claude-agent/deploy.sh
```

`deploy.sh` applies the Namespace, ServiceAccount, the managed-settings ConfigMap (with your organization UUID substituted in) and the StatefulSet, then waits for the Pod.

Check:

```bash
kubectl get pod claude-0 -n claude-agent                 # Running, 1/1
kubectl get nodes -L kubernetes.io/arch                  # amd64 expected; if arm64, stop (image is amd64)
kubectl exec claude-0 -n claude-agent -- claude doctor   # managed settings source, no settings errors
```

## 2. Log in (you)

```bash
kubectl exec -it claude-0 -n claude-agent -- claude auth login
```

Open the printed URL in a local browser, approve, and paste the code back into the terminal.

If login fails with an organization mismatch, `CLAUDE_ORG_UUID` is wrong. Fix it, run `deploy.sh` again, and recreate the Pod: `kubectl delete pod claude-0 -n claude-agent`.

## 3. Check the login

```bash
kubectl exec claude-0 -n claude-agent -- claude auth status      # shows a claude.ai login
kubectl exec claude-0 -n claude-agent -- claude -p "hello"       # answers
```

Deleting the Pod keeps the login (it lives on the PVC). Deleting the PVC removes it, because the StorageClass reclaim policy is `Delete`.

## 4. Then

Tell the agent the login is done; it runs the four verification checks (`verification.md`).
