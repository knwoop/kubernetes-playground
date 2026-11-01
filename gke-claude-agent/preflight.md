# Cluster preflight

Facts the manifests depend on. No project, cluster name or region is recorded here;
they come from direnv variables (`GCP_PROJECT_ID`, `GKE_LOCATION`, `GKE_CLUSTER_NAME`).

## Local prerequisites

```bash
gcloud components install kubectl gke-gcloud-auth-plugin
gcloud container clusters get-credentials "$GKE_CLUSTER_NAME" --location "$GKE_LOCATION" --project "$GCP_PROJECT_ID"
```

## Findings

| Item | Result | Evidence |
|------|--------|----------|
| Cluster mode | Autopilot | `gcloud container clusters describe ... --format="value(autopilot.enabled)"` → `True` |
| Node architecture | amd64 expected; **not yet observed** | Autopilot has no nodes until a Pod is scheduled (`kubectl get nodes` → `No resources found`). Autopilot's default compute class is x86. Confirm with `kubectl get nodes -L kubernetes.io/arch` once `claude-0` is scheduled (deploy child). If it is arm64, rebuild the image with `--platform linux/arm64`. |
| Default StorageClass | `standard-rwo` (PD CSI), reclaim `Delete`, `WaitForFirstConsumer` | `kubectl get storageclass` |
| NetworkPolicy enforcement | Yes, Dataplane V2 | `networkConfig.datapathProvider` → `ADVANCED_DATAPATH`, so `FQDNNetworkPolicy` is available |
| `kubectl` reachable | OK | `kubectl config current-context` points at the cluster; `kubectl get storageclass` succeeds |
| RBAC | OK | `kubectl auth can-i create statefulsets -n default` → `yes` |

## Consequences for the plan

- Reclaim policy `Delete`: deleting the PVC deletes the login state. Deleting only the Pod keeps it.
- Autopilot admission applies: requests must equal limits for ephemeral storage, and the Pod must meet the restricted profile.
- First schedule can take a minute while Autopilot provisions a node.
