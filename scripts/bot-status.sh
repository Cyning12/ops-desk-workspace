#!/bin/bash
# bot-status.sh — 一眼看清两个 superagent 部署的工作状态
# 用法: scripts/bot-status.sh    （任何会话/窗口直接运行；无状态，全实时查询）
set -euo pipefail
cd "$(dirname "$0")/.."

deploy() { # name port repo
  local name="$1" port="$2" repo="$3" api="http://127.0.0.1:$2/orchestrator/api"
  local H='-H x-orchestrator-request:1'
  echo "━━━ $name (127.0.0.1:$port) ━━━"
  if ! curl -sf -m 5 "$api/overview" $H > /tmp/bot-ov.json 2>/dev/null; then
    echo "  ✗ 面板不可达——服务可能停了: scripts/dsh-superagent start --profile $name --url http://127.0.0.1:$port"; echo; return
  fi
  jq -r '"  流水线: 收\(.flow.received) 判\(.flow.judged) 受\(.flow.accepted) 滤\(.flow.filtered) | 执行: 跑\(.executor.running) 队\(.executor.queued)/\(.executor.maxWorkers)",
    (if (.problems|length)>0 then "  ⚠ 问题: \(.problems|map(.detail//.code)|join(" / "))" else "  ✓ 无告警" end)' /tmp/bot-ov.json
  local tickets
  tickets=$(curl -sf -m 5 "$api/tickets?limit=10" $H | jq -r '[.items[] | select(.stage != "idle" and .stage != "ended") | "  · \(.id[0:8]) [\(.stage)] \((.title//"")[0:52])"] | if length==0 then ["  · 无活动工单"] else . end | join("\n")')
  echo "$tickets"
  echo
}

deploy "superagent (api)"  3082 Cyning12/ops-desk-api
deploy "superagent-web"    3083 Cyning12/ops-desk-web
echo "━━━ 待验收队列（open PR · 出货即审） ━━━"
gh pr list --repo Cyning12/ops-desk-api --limit 5 --json number,title --jq '.[] | "  api  #\(.number) \(.title[0:52])"' 2>/dev/null || true
gh pr list --repo Cyning12/ops-desk-web --limit 5 --json number,title --jq '.[] | "  web  #\(.number) \(.title[0:52])"' 2>/dev/null || true
echo "（面板 token: .artifacts 日志 grep token=；本脚本只读，任意会话可跑）"
