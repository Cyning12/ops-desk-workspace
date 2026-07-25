#!/usr/bin/env bash
# Ops Desk production deploy (run from ops-desk-workspace/deploy/).
#
# Usage:
#   ./deploy.sh [--skip-web] [--skip-api] [--nginx-only]
#
# Prerequisites (first time, see README):
#   - ssh alias `ops-desk` works (key auth)
#   - server /opt/ops-desk/.env filled (see .env.example in this dir)
#   - SSL certs at /etc/nginx/ssl/cynaya.cn.{crt,key}
#   - web dist built locally: cd ../../ops-desk-web && pnpm build
set -euo pipefail

SSH_HOST="${SSH_HOST:-ops-desk}"
REMOTE_ROOT="/opt/ops-desk"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_DIR="$(cd "$SCRIPT_DIR/../../ops-desk-api" && pwd)"
WEB_DIST="$(cd "$SCRIPT_DIR/../../ops-desk-web" && pwd)/dist"

SKIP_WEB=0; SKIP_API=0; NGINX_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --skip-web) SKIP_WEB=1 ;;
    --skip-api) SKIP_API=1 ;;
    --nginx-only) NGINX_ONLY=1 ;;
    *) echo "未知参数: $arg" >&2; exit 1 ;;
  esac
done

echo "==> 检查 SSH 连通性"
ssh -o BatchMode=yes -o ConnectTimeout=10 "$SSH_HOST" true || {
  echo "SSH 不通：检查 ssh config 别名 $SSH_HOST 与 agent" >&2; exit 1; }

if [[ "$NGINX_ONLY" == "1" ]]; then
  echo "==> 仅更新 Nginx 配置"
  scp "$SCRIPT_DIR/nginx/ops-desk.conf" "$SSH_HOST:/tmp/ops-desk.conf"
  ssh "$SSH_HOST" 'sudo cp /tmp/ops-desk.conf /etc/nginx/sites-available/ops-desk \
    && sudo ln -sf /etc/nginx/sites-available/ops-desk /etc/nginx/sites-enabled/ops-desk \
    && sudo nginx -t && sudo systemctl reload nginx'
  echo "==> Nginx 已更新并重载"
  exit 0
fi

if [[ "$SKIP_API" == "0" ]]; then
  echo "==> 同步后端源码 -> $REMOTE_ROOT/api"
  ssh "$SSH_HOST" "sudo mkdir -p $REMOTE_ROOT/api && sudo chown -R \$USER:\$USER $REMOTE_ROOT"
  rsync -az --delete \
    --exclude '.venv' --exclude '__pycache__' --exclude '.git' \
    --exclude '.env' --exclude 'node_modules' --exclude '.pytest_cache' \
    "$API_DIR/" "$SSH_HOST:$REMOTE_ROOT/api/"

  echo "==> 同步部署产物 -> $REMOTE_ROOT/deploy"
  rsync -az --delete "$SCRIPT_DIR/" "$SSH_HOST:$REMOTE_ROOT/deploy/"
fi

if [[ "$SKIP_WEB" == "0" ]]; then
  [[ -d "$WEB_DIST" ]] || { echo "缺少 $WEB_DIST：先执行 pnpm build" >&2; exit 1; }
  echo "==> 同步前端构建产物 -> $REMOTE_ROOT/web/dist（保留上一份备份）"
  ssh "$SSH_HOST" "mkdir -p $REMOTE_ROOT/web && \
    [[ -d $REMOTE_ROOT/web/dist ]] && mv $REMOTE_ROOT/web/dist $REMOTE_ROOT/web/dist.bak.\$(date +%Y%m%d%H%M%S) || true"
  rsync -az --delete "$WEB_DIST/" "$SSH_HOST:$REMOTE_ROOT/web/dist/"
fi

if [[ "$SKIP_API" == "0" ]]; then
  echo "==> 构建并重启容器（含 alembic 迁移）"
  ssh "$SSH_HOST" "cd $REMOTE_ROOT/deploy && \
    sudo docker compose -f docker-compose.prod.yml --env-file $REMOTE_ROOT/.env up -d --build"

  echo "==> 等待 API 健康检查"
  for i in $(seq 1 30); do
    if ssh "$SSH_HOST" "curl -fsS http://127.0.0.1:8000/health" > /dev/null 2>&1; then
      echo "API healthy"; break
    fi
    [[ "$i" == "30" ]] && { echo "API 健康检查超时" >&2; exit 1; }
    sleep 2
  done
fi

echo "==> 更新 Nginx 配置（幂等）"
"$0" --nginx-only

echo "==> 完成：https://www.cynaya.cn/"
echo "提示：首次部署后还需初始化数据（见 README §首次初始化）"
