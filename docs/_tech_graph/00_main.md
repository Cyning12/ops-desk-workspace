---
graph_id: 00_main
version: 2026-10-22
generated_at: sha256-1ad8b3ee5813a0ae
source: 00_main.graph.yaml
---

# ops-desk-workspace 跨仓总图（最小骨架）

四仓锚点级总图；契约与数据流细节另 task 充实。四仓均接入 SpecWave（各仓自钉）。

## Mermaid

```mermaid
flowchart TB
    workspace["ops-desk-workspace"]
    api["ops-desk-api"]
    web["ops-desk-web"]
    ios["ops-desk-ios"]
    compose["docker-compose"]

    workspace -->|"契约 / 总 task"| api
    workspace -->|"契约 / 总 task"| web
    workspace -->|"契约 / 总 task"| ios
    workspace -->|"部署编排"| compose
    web -->|"HTTP / SSE"| api
    ios -->|"HTTP / SSE"| api

    classDef phase fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef doc fill:#fff8e1,stroke:#ff6f00,stroke-width:1px
    classDef infra fill:#e8f5e9,stroke:#2e7d32,stroke-width:1px
    class compose phase
    class workspace,api,web,ios doc
```

## Structured Data

### Nodes

| ID | Label | Kind |
|----|-------|------|
| workspace | ops-desk-workspace | struct |
| api | ops-desk-api | struct |
| web | ops-desk-web | struct |
| ios | ops-desk-ios | struct |
| compose | docker-compose | flow |

### Edges

| From | To | Mark | Type | Label | Anchors |
|------|----|------|------|-------|---------|
| workspace | api | -> | depends_on | 契约 / 总 task |  |
| workspace | web | -> | depends_on | 契约 / 总 task |  |
| workspace | ios | -> | depends_on | 契约 / 总 task |  |
| workspace | compose | -> | depends_on | 部署编排 |  |
| web | api | -> | depends_on | HTTP / SSE |  |
| ios | api | -> | depends_on | HTTP / SSE |  |

## Sub-graph Links

- `Struct`: [`01_struct.md`](01_struct.md)（手写 · 无 `.graph.yaml`）
- `Version`: [`02_version.md`](02_version.md)（手写 · 无 `.graph.yaml`）
- 子图编辑源见 `docs/_tech_graph/*.graph.yaml`

