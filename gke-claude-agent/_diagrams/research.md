# GKE Claude Code agent research, as diagrams

Source: [research.md](../research.md)

## Map

```mermaid
flowchart LR
  A["Where does the agent run?"] -->|"Pod"| B["What does the pod need?"]
  A -->|"GKE"| C["Which cluster mode?"]
  B -->|"Auth"| D["Which token wins?"]
  C -->|"Workload shape"| E["How is it run?"]
```

## Where does the agent run?

```mermaid
flowchart LR
  repo["Repo: empty, one directory"]:::boundary
  proj["Google Cloud project: billing on"]
  apis["container, compute, secretmanager: off"]:::changed
  gke["GKE cluster: not created"]:::changed
  pod["Pod: claude CLI / Agent SDK"]
  api["api.anthropic.com, claude.ai, platform.claude.com"]:::boundary
  state["~/.claude: lost on restart"]
  repo --> proj
  proj --> apis
  apis -->|"enable first"| gke
  gke --> pod
  pod -->|"egress 443"| api
  pod --> state

  classDef changed fill:#fff8c5,stroke:#9a6700,stroke-width:2px,color:#1f2328
  classDef boundary fill:#eaeef2,stroke:#8c959f,stroke-dasharray:3 3,color:#57606a
```

Sources: [research.md, Google Cloud project state](../research.md), [Claude Code runtime](../research.md)

## Which cluster mode?

```mermaid
flowchart TB
  mode{"Cluster mode"}
  mode -->|"Autopilot"| ap["Regional, free tier eligible"]
  mode -->|"Standard zonal"| sz["Free tier eligible"]
  mode -->|"Standard regional"| sr["Fee not covered by free tier"]
  ap --> ap1["Privileged pods blocked"]
  ap --> ap2["NET_RAW dropped"]
  ap --> ap3["gVisor on by default"]
  sz --> sz1["Privileged allowed"]
  sz --> sz2["gVisor per node pool"]
  sr --> sz1
```

Sources: [research.md, GKE modes](../research.md)

## Which token wins?

```mermaid
flowchart TB
  start["Claude Code starts in the pod"] --> c1{"Bedrock / Vertex env set?"}
  c1 -->|"yes"| r1["Cloud provider"]
  c1 -->|"no"| c2{"ANTHROPIC_AUTH_TOKEN set?"}
  c2 -->|"yes"| r2["Auth token"]
  c2 -->|"no"| c3{"ANTHROPIC_API_KEY set?"}
  c3 -->|"yes"| r3["API key, API billing"]
  c3 -->|"no"| c4{"CLAUDE_CODE_OAUTH_TOKEN set?"}
  c4 -->|"yes"| c5{"--bare used?"}
  c4 -->|"no"| r6["Other sources or login"]
  c5 -->|"yes"| r5["Token ignored"]
  c5 -->|"no"| r4["Subscription, plan limits"]
```

Only the first four rungs of the precedence list are drawn; later ones (`apiKeyHelper`, profiles) are collapsed into "Other sources or login".

Sources: [research.md, Claude Code runtime](../research.md)

## How is it run?

```mermaid
flowchart LR
  shape{"Workload shape"}
  shape -->|"Job / CronJob per task"| j["Clean state, cron trigger documented"]
  shape -->|"Long-lived pod + PVC"| l["Keeps ~/.claude"]
  shape -->|"agent-sandbox CRDs"| s["Pause/resume, warm pools, self-managed controller"]
  j --> jq["No session state without volume"]
  l --> lq["Lost on node move without PVC"]
  s --> sq["API v1beta1, maturity unlabeled"]
```

Sources: [research.md, platform options](../research.md)
