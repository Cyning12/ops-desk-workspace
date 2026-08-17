# 完整环境配置与准备工作手册

> 更新日期：2026-07-15  
> 适用范围：Ops Desk Kimi Code v1 迁移项目  
> 目标：让你在 AI 输出代码前，完成所有基础设施和仓库准备工作  
> **生产已上线后改 Flag**：见 [`02-prod-env-reload.md`](./02-prod-env-reload.md)（改 `.env` ≠ 进容器；不要 `restart`）

---

## 1. 私有仓库命名与创建

### 1.1 推荐的 GitHub 私有仓库名

| 仓库名 | 用途 | 可见性 |
|---|---|---|
| `ops-desk-workspace` | AI 总调度、文档、任务单、docker-compose、总技术图谱 | Private |
| `ops-desk-web` | Vue3 + TypeScript + Element Plus 前端 | Private |
| `ops-desk-api` | FastAPI + LangGraph + SQLAlchemy 后端 | Private |
| `ops-desk-ios` | Swift + SwiftUI iOS 应用 | Private |

### 1.2 创建步骤

1. 登录 GitHub：https://github.com
2. 点击右上角 `+` → `New repository`
3. 依次创建 4 个仓库，均选择：
   - Owner：你的 GitHub 账号
   - Repository name：上述名称
   - Description：按需填写
   - **Private**（必须）
   - 不勾选 `Add a README file`（后续由 AI 或你自行初始化）
   - 不勾选 `.gitignore` / license
4. 记录每个仓库的 HTTPS/SSH 地址，后续 CI/CD 用。

### 1.3 本地目录结构建议

```
~/Projects/
├── ops-desk-workspace/          # 总调度
├── ops-desk-web/                # 前端
├── ops-desk-api/                # 后端
└── ops-desk-ios/                # iOS
```

后续 `ops-desk-workspace/docker-compose.yml` 会引用同级目录的 `../ops-desk-api` 和 `../ops-desk-web`。

---

## 2. 腾讯云服务器购买

### 2.1 推荐配置

| 配置 | 推荐值 |
|---|---|
| 产品 | 腾讯云轻量应用服务器 Lighthouse |
| 地域 | 上海 / 广州 / 北京（离你最近） |
| 实例 | 2核4G5M（¥80–110/月） |
| 系统盘 | 60GB SSD |
| 流量包 | 500GB/月 |
| 镜像 | Ubuntu 22.04 LTS / Debian 12 |

### 2.2 购买链接

1. 腾讯云 Lighthouse 首页：https://cloud.tencent.com/product/lighthouse
2. 新用户特惠（通常 ¥40–80/年）：https://cloud.tencent.com/act/pro/lighthouse

### 2.3 购买后操作

1. 进入 [腾讯云控制台](https://console.cloud.tencent.com/)
2. 找到 Lighthouse 实例，记录：
   - 公网 IP
   - 默认用户名（通常是 `root` 或 `ubuntu`）
3. 重置密码（首次登录需要）
4. 在控制台生成 SSH 密钥对，下载私钥 `.pem` 文件保存到 `~/.ssh/`
5. 绑定密钥到实例

---

## 3. 域名注册

### 3.1 推荐域名

- 主域名：`.com` 通用，首年 ¥60–80
- 省钱可选：`.cn`，首年 ¥30–50

### 3.2 注册链接

腾讯云域名注册：https://cloud.tencent.com/product/domains

### 3.3 注册后操作

1. 购买域名
2. 完成**域名实名认证**（个人：身份证；企业：营业执照）
3. 等待 1–3 工作日实名通过
4. 记录域名，后续 ICP 备案用

---

## 4. ICP 备案

### 4.1 备案入口

腾讯云 ICP 备案：https://cloud.tencent.com/product/ba

### 4.2 备案流程

1. 登录腾讯云备案系统
2. 填写主体信息（个人/企业）
3. 填写网站信息：
   - 网站名称：**不能含**"平台""系统""服务""商城"等商业词
   - 推荐名称：如 "ops-desk-notes"、"个人代码看板"、"技术笔记"
   - 网站内容：选择 "其他/个人技术笔记"
4. 上传身份证、人脸识别
5. 腾讯云初审（1–3 工作日）
6. 管局审核（10–20 工作日）
7. 获取备案号

### 4.3 备案期间开发策略

- 备案期间不能用 80/443 端口对外服务。
- 可用服务器 IP + 非标准端口开发测试，如 `https://1.2.3.4:8443`。
- 本地开发使用 `localhost` + Vite proxy，不依赖域名。

---

## 5. SSL 证书

### 5.1 免费证书

1. 腾讯云 SSL 证书：https://cloud.tencent.com/product/ssl
2. 选择 "免费版 DV SSL"（TrustAsia）
3. 绑定你的域名
4. 验证域名所有权（DNS 验证或文件验证）
5. 下载 Nginx 格式证书：`xxx.crt` + `xxx.key`

### 5.2 或自动续期

备案通过后可使用 Let's Encrypt + acme.sh：

```bash
curl https://get.acme.sh | sh
~/.acme.sh/acme.sh --issue -d your-domain.com --nginx
```

---

## 6. DNS 解析

备案通过后：

1. 进入腾讯云 DNSPod 控制台
2. 添加 A 记录：
   - 主机记录：`@`
   - 记录类型：`A`
   - 记录值：你的服务器公网 IP
3. 可选添加 `www` A 记录
4. 等待 DNS 生效（通常几分钟到几小时）

---

## 7. 服务器初始化

### 7.1 SSH 登录

```bash
chmod 600 ~/.ssh/your-key.pem
ssh -i ~/.ssh/your-key.pem root@YOUR_SERVER_IP
```

### 7.2 安全基线

```bash
# 创建非 root 用户（可选但推荐）
adduser ops
usermod -aG sudo ops

# 禁用密码登录（确保密钥登录成功后执行）
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin yes/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
systemctl restart sshd

# 安装 fail2ban
apt update
apt install -y fail2ban ufw
ufw allow 22
ufw allow 80
ufw allow 443
ufw enable
```

### 7.3 安装 Docker + Docker Compose

```bash
# 安装 Docker
apt update
apt install -y ca-certificates curl gnupg lsb-release
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 将 ops 用户加入 docker 组
usermod -aG docker ops

# 验证
docker --version
docker compose version
```

### 7.4 安装其他工具

```bash
apt install -y git nginx vim htop
```

---

## 8. 本地开发环境准备

### 8.1 必需工具

| 工具 | 版本/说明 |
|---|---|
| Node.js | ≥18（推荐 20 LTS） |
| pnpm | ≥8 |
| Python | 3.11 或 3.12 |
| uv 或 pip | 包管理 |
| Git | 任意 |
| Docker Desktop | 本地测试 PG 用（可选） |
| Xcode | iOS 开发（Mac 必需） |

### 8.2 安装命令（macOS）

```bash
# Node.js + pnpm
brew install node@20 pnpm

# Python + uv
brew install python@3.12
curl -LsSf https://astral.sh/uv/install.sh | sh

# Git
brew install git

# Docker Desktop
brew install --cask docker
```

### 8.3 克隆仓库

```bash
cd ~/Projects
git clone git@github.com:YOUR_USERNAME/ops-desk-workspace.git
git clone git@github.com:YOUR_USERNAME/ops-desk-web.git
git clone git@github.com:YOUR_USERNAME/ops-desk-api.git
git clone git@github.com:YOUR_USERNAME/ops-desk-ios.git
```

---

## 9. 环境变量模板

### 9.1 ops-desk-api/.env

```bash
# 数据库
DATABASE_URL=postgresql+asyncpg://ops:YOUR_DB_PASSWORD@db:5432/opsdesk

# 鉴权
OPS_DESK_AUTH_MODE=db
OPS_DESK_SECRET=your-random-secret-at-least-32-chars
SESSION_TTL_SECONDS=86400

# LLM
OPS_LLM_PROVIDER=siliconflow
SILICONFLOW_API_KEY=your-siliconflow-key
OPS_LLM_MODEL=deepseek-ai/DeepSeek-V4-Pro
BAILIAN_API_KEY=your-bailian-key
BAILIAN_MODEL=deepseek-v4-pro

# admin sync
SYNC_ADMIN_SECRET=your-sync-admin-secret
```

### 9.2 ops-desk-workspace/.env

```bash
DB_PASSWORD=your-strong-db-password
OPS_LLM_PROVIDER=siliconflow
SILICONFLOW_API_KEY=your-siliconflow-key
BAILIAN_API_KEY=your-bailian-key
OPS_DESK_SECRET=your-random-secret-at-least-32-chars
SYNC_ADMIN_SECRET=your-sync-admin-secret
```

### 9.3 ops-desk-web/.env

```bash
VITE_API_BASE_URL=/api
```

---

## 10. CI/CD 准备

### 10.1 GitHub Actions Secrets

在每个仓库 Settings → Secrets and variables → Actions 中添加：

**ops-desk-web / ops-desk-api 共用：**

| Secret | 说明 |
|---|---|
| `HOST` | 服务器公网 IP |
| `USERNAME` | 服务器用户名 |
| `SSH_PRIVATE_KEY` | SSH 私钥内容 |
| `DB_PASSWORD` | PostgreSQL 密码 |
| `SILICONFLOW_API_KEY` | SiliconFlow API Key |
| `BAILIAN_API_KEY` | 百炼 API Key |
| `OPS_DESK_SECRET` | 鉴权 Secret |
| `SYNC_ADMIN_SECRET` | Sync 鉴权 Secret |

### 10.2 部署密钥

在服务器 `~/.ssh/authorized_keys` 中添加 GitHub Actions 用的 deploy key。

### 10.3 Workflow 触发约束（强制）

个人 Free + **私有仓**无法启用 Branch Protection / Rulesets（服务端拦不住直推 `main`）。因此四仓所有 GitHub Actions **必须同时覆盖 PR 与 main**，避免只配 `pull_request` 时直推漏跑、只配 `push` 时 PR 看不到结果。

**新建或修改 `.github/workflows/*.yml` 时，`on` 至少包含：**

```yaml
on:
  pull_request:
  push:
    branches: [main]
```

| 触发 | 作用 |
|---|---|
| `pull_request` | 合入前在 PR 上看到检查结果 |
| `push` → `main` | 直推或 merge 进 main 后仍会跑，防遗漏 |

说明：

- 不要求当前就配置「Required status checks」（同上，Free 私有仓不可强制）。
- Ruleset 模板见 `docs/contracts/github-main-ruleset-v1.json`；升级 Pro / Team 后可导入并再开门禁。
- 约定：日常仍走 `feat/*` → PR → Merge；不要依赖直推。

---

## 11. 备份策略

### 11.1 数据库自动备份

在服务器上创建 `/opt/backup/backup.sh`：

```bash
#!/bin/bash
DATE=$(date +%Y%m%d-%H%M%S)
docker exec ops-desk-db pg_dump -U ops opsdesk > /opt/backup/opsdesk-${DATE}.sql
gzip /opt/backup/opsdesk-${DATE}.sql
# 可选上传到 COS
# /usr/local/bin/coscmd upload /opt/backup/opsdesk-${DATE}.sql.gz /backups/
find /opt/backup -name "*.gz" -mtime +7 -delete
```

加入 crontab：

```bash
0 3 * * * /opt/backup/backup.sh
```

### 11.2 服务器快照

- 每周一次 Lighthouse 快照。
- 重大升级前手动快照。

---

## 12. 购买与准备清单

| 步骤 | 状态 | 备注 |
|---|---|---|
| [ ] 创建 4 个 GitHub 私有仓库 | | `ops-desk-workspace/web/api/ios` |
| [ ] 购买腾讯云 Lighthouse 2C4G5M | | 记录公网 IP |
| [ ] 配置 SSH 密钥登录 | | 下载 `.pem` |
| [ ] 购买域名 | | `.com` 或 `.cn` |
| [ ] 域名实名认证 | | 等待 1–3 工作日 |
| [ ] 提交 ICP 备案 | | 等待 10–20 工作日 |
| [ ] 服务器初始化（Docker、Nginx、安全基线） | | |
| [ ] 本地安装 Node/Python/Docker | | |
| [ ] 克隆 4 个仓库到本地 | | |
| [ ] 配置 GitHub Actions Secrets | | |
| [ ] ICP 通过后配置 DNS + SSL | | |
| [ ] 配置数据库自动备份 | | |

---

## 13. 预计首月支出

| 项目 | 费用 |
|---|---|
| Lighthouse 2C4G5M（按新用户首单） | ¥50–100/年 |
| 域名 `.com` | ¥60–80/年 |
| SSL 证书 | ¥0 |
| LLM API 调用 | ¥50–200/月 |
| **首月合计** | **约 ¥200–400** |

---

## 14. 人可以做、AI 暂时不做的事

以下工作建议你在 AI 输出代码前自行完成：

1. 购买服务器和域名
2. 完成域名实名认证和 ICP 备案提交
3. 创建 4 个 GitHub 私有仓库
4. 配置服务器 SSH 密钥和安全组
5. 安装 Docker、Nginx
6. 配置 GitHub Actions Secrets
7. 申请 SiliconFlow / 百炼 API Key

AI 下一步可以并行输出的内容：

1. 后端数据库 DDL
2. `ops-desk-workspace` 的 harness 骨架 + `docker-compose.yml`
3. `ops-desk-api` 项目骨架（FastAPI + LangGraph + SQLAlchemy）

---

## 15. 命名最终确认

| 项目 | 最终命名 |
|---|---|
| AI 总调度工作空间 | `ops-desk-workspace` |
| Vue3 前端 | `ops-desk-web` |
| FastAPI 后端 | `ops-desk-api` |
| iOS 应用 | `ops-desk-ios` |
| 主域名 | 由你决定（如 `opsdesk.yourdomain.com`） |
| 服务器主机名 | 可由你决定（如 `ops-desk-prod`） |
