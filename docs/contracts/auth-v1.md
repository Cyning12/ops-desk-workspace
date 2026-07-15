# Auth API v1 契约

> 更新日期：2026-07-15  
> 范围：Ops Desk 登录、Session、登出

---

## 1. 设计原则

- 不开放注册，仅支持预置邀请密钥登录。
- 使用 DB Session：登录成功后后端创建 session，写入 `ops_sessions` 表。
- 通过 HttpOnly Cookie `ops_session` 传递 session。
- 角色：`viewer` / `maintainer`。

---

## 2. 数据模型

### 2.1 ops_users

| 字段 | 类型 | 说明 |
|---|---|---|
| id | UUID | 主键 |
| username | string | 用户名（展示用） |
| role | enum | `viewer` / `maintainer` |
| created_at | datetime | 创建时间 |

### 2.2 ops_invite_tokens

| 字段 | 类型 | 说明 |
|---|---|---|
| id | UUID | 主键 |
| token_hash | string | 邀请密钥的 SHA-256 哈希 |
| role | enum | 该密钥对应角色 |
| expires_at | datetime | 过期时间 |
| used_at | datetime | 使用时间 |
| created_at | datetime | 创建时间 |

### 2.3 ops_sessions

| 字段 | 类型 | 说明 |
|---|---|---|
| id | UUID | 主键，作为 session_id |
| user_id | UUID | 关联 ops_users |
| role | enum | 快照角色 |
| expires_at | datetime | 过期时间 |
| created_at | datetime | 创建时间 |

---

## 3. 接口

### 3.1 POST /api/ops/login

**说明**：使用邀请密钥登录，成功后设置 session cookie。

**Request**

```http
POST /api/ops/login
Content-Type: application/json
```

```json
{
  "token": "invitation-secret-key"
}
```

**Response 200**

```http
Set-Cookie: ops_session=session-id-uuid; Path=/; HttpOnly; SameSite=Lax; Secure
```

```json
{
  "ok": true,
  "role": "viewer"
}
```

**Response 401**

```json
{
  "ok": false,
  "error": "Invalid or expired invitation token",
  "code": "INVITE_INVALID"
}
```

**Response 503**

```json
{
  "ok": false,
  "error": "Server authentication not configured",
  "code": "AUTH_NOT_CONFIGURED"
}
```

---

### 3.2 POST /api/ops/logout

**说明**：清除当前 session。

**Request**

```http
POST /api/ops/logout
Cookie: ops_session=session-id-uuid
```

**Response 200**

```http
Set-Cookie: ops_session=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0
```

```json
{
  "ok": true
}
```

---

### 3.3 GET /api/ops/auth/me

**说明**：获取当前登录用户基本信息，用于前端显示头像/角色。

**Request**

```http
GET /api/ops/auth/me
Cookie: ops_session=session-id-uuid
```

**Response 200**

```json
{
  "ok": true,
  "user": {
    "id": "uuid",
    "username": "ops-user",
    "role": "maintainer"
  }
}
```

**Response 401**

```json
{
  "ok": false,
  "error": "Unauthorized",
  "code": "UNAUTHORIZED"
}
```

---

## 4. 鉴权中间件

所有 `/api/ops/*` 路由（除 `/api/ops/login` 外）必须：

1. 从 Cookie 读取 `ops_session`。
2. 查询 `ops_sessions` 表，检查是否过期。
3. 未登录返回 401。
4. 需要 maintainer 的路由额外检查 `role == "maintainer"`，否则返回 403。

---

## 5. 安全约束

- Cookie 必须 `HttpOnly`、`SameSite=Lax`。
- 生产环境必须 `Secure`。
- 邀请密钥不存储明文，只存 SHA-256 hash。
- Session 过期时间默认 24 小时。
- 登录失败不提示具体是 token 不存在还是已过期。

---

## 6. 前端/iOS 行为

| 端 | 行为 |
|---|---|
| web | 登录表单 → 成功后跳转 `/ops/kimi-code`；axios 自动携带 cookie |
| ios | 登录页 → 成功后保存 session cookie 到 URLSession 配置；后续请求自动携带 |

---

## 7. 环境变量

```bash
OPS_DESK_AUTH_MODE=db
OPS_DESK_SECRET=your-random-secret-at-least-32-chars  # 用于额外签名，可选
SESSION_TTL_SECONDS=86400
```
