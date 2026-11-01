# PoC: Claude Code in a GKE Pod, driven by `kubectl exec`

Status: files written, **nothing built, applied or run**. `kubectl` is not installed on this machine and the project has no cluster (`container.googleapis.com` was disabled when last checked).

## Files

| file | purpose |
|---|---|
| `Dockerfile` | official installer, non-root user `claude` (uid 1000), `sleep infinity` |
| `k8s/` | Namespace `claude-poc`, ServiceAccount (no token, no GCP identity), managed-settings ConfigMap, StatefulSet `claude` (replicas 1, PVC at `/home/claude/.claude`), optional `networkpolicy.yaml` (not in the kustomization) |
| `claude-pod` | `claude-pod <conversation-key> "<prompt>"` |

## Build and apply

Nothing project-specific is stored in the files. Set these in your shell:

```bash
export PROJECT_ID=...        # GCP project
export REGION=...            # Artifact Registry region
export REPO=...              # Artifact Registry repository
export CLAUDE_ORG_UUID=...   # your organization UUID (forceLoginOrgUUID)
export CLAUDE_POC_IMAGE="$REGION-docker.pkg.dev/$PROJECT_ID/$REPO/claude-code-poc:latest"

docker build -t "$CLAUDE_POC_IMAGE" . && docker push "$CLAUDE_POC_IMAGE"
kubectl kustomize k8s | envsubst '${CLAUDE_POC_IMAGE} ${CLAUDE_ORG_UUID}' | kubectl apply -f -
```

## Login (human, in the Pod)

1. `kubectl exec -it -n claude-poc claude-0 -- claude auth login`
2. Open the printed URL in a local browser and approve.
3. Paste the displayed code into the terminal.
4. Check: `kubectl exec -n claude-poc claude-0 -- claude -p "hello"`

## Verification

1. `claude-pod a "The password is banana. Remember it."`, then `claude-pod a "What's the password?"` should answer banana.
2. `claude-pod b "What's the password?"` should not know it.
3. The request ends mid-sentence at "After deleting and recreating"; presumed: delete and recreate the Pod (`kubectl delete pod -n claude-poc claude-0`), then repeat step 1's second command. The login and session should survive because they live on the PVC.

## Notes

- The same key always maps to the same session ID (UUIDv5 over a fixed namespace UUID in the script).
- The wrapper only checks that `<uuid>.jsonl` exists; it never reads session or credential contents.
- Tools are limited to `Read,Grep,Glob`.
- `permissions.deny` guards the credentials file against Claude's own Read tool; it is not a filesystem boundary.
