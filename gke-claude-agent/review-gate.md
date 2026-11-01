# Review gate

Before anything was applied to the cluster, the image and manifests were shown to the user.

| Item | Shown | Result |
|------|-------|--------|
| `image/Dockerfile`, `image/build.sh`, `image/cloudbuild.yaml` | yes, with the verified version, uid and empty config dir | approved as shown |
| `k8s/namespace.yaml`, `serviceaccount.yaml`, `configmap-managed-settings.yaml` | yes | approved as shown |
| `k8s/statefulset.yaml` | yes, with the server-side dry-run output | approved as shown |

Approved on 2026-11-02, with no requested changes.

## Still open at approval time

These are review findings the user has not decided yet. They do not block the apply and can follow as later changes.

- Managed deny rules cover only `Read` of the credentials file; the read-only tool limit is enforced by the `claude-pod` wrapper. Whether to add Bash/Edit/Write deny rules is undecided.
- The cluster API endpoint is public with no authorized networks. Whether to restrict it is undecided.
- Node architecture is not yet observed (Autopilot has no nodes until a Pod schedules); it is checked right after the first schedule.
