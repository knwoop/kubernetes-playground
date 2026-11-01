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
| Node architecture | amd64 expected; **not yet observed** | Autopilot has no nodes until a Pod is scheduled (`kubectl get nodes` → `No resources found`). Autopilot's default compute class is x86. The deploy child owns this check: after `claude-0` is scheduled, run `kubectl get nodes -L kubernetes.io/arch`. If it is arm64, stop and ask before continuing; the image must then be rebuilt with `PLATFORM=linux/arm64` (see `image/build.sh`), which needs a native arm64 builder and is untested. |
| Default StorageClass | `standard-rwo` (PD CSI), reclaim `Delete`, `WaitForFirstConsumer` | `kubectl get storageclass` |
| NetworkPolicy enforcement | Yes, Dataplane V2 | `networkConfig.datapathProvider` → `ADVANCED_DATAPATH` |
| FQDNNetworkPolicy | **Not enabled** | Dataplane V2 is necessary but not sufficient: the feature is off by default (`gcloud container clusters update --help` lists `--enable-fqdn-network-policy`) and `kubectl get crd` shows no `fqdnnetworkpolicies.networking.gke.io`. Enabling it is a cluster change, owned by the NetworkPolicy child; until then only standard NetworkPolicy (DNS and IP based) is available. Requirements: https://docs.cloud.google.com/kubernetes-engine/docs/how-to/fqdn-network-policies |
| `kubectl` reachable | OK | `kubectl config current-context` points at the cluster; `kubectl get storageclass` succeeds |
| RBAC | OK | In the deploy namespace: `kubectl auth can-i create statefulsets -n claude-agent`, `... persistentvolumeclaims ...` and `... pods/exec ...` → `yes` each (the namespace need not exist yet for this check) |

## Consequences for the plan

- Reclaim policy `Delete`: deleting the PVC deletes the login state. Deleting only the Pod keeps it.
- Autopilot admission applies: requests must equal limits for ephemeral storage, and the Pod must meet the restricted profile.
- First schedule can take a minute while Autopilot provisions a node.
