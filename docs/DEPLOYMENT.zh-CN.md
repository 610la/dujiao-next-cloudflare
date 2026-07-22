# Cloudflare 部署说明

## 1. 部署前准备

需要准备：

- Cloudflare 账号
- Node.js 22 或更高版本
- pnpm 10 或更高版本
- 一个由 Cloudflare 托管 DNS 的域名（使用自定义域名时需要）

安装依赖：

```bash
pnpm install
```

登录 Cloudflare：

```bash
pnpm exec wrangler login
```

## 2. 设置项目公开配置

编辑 `config/project.json`：

```json
{
  "adminPath": "change-this-admin-path",
  "siteUrl": "https://shop.example.com"
}
```

- `adminPath`：后台页面路径，只能使用英文字母、数字、短横线和下划线。
- `siteUrl`：站点最终访问地址，不要以 `/` 结尾。

这两个值不是密钥，但应在首次构建前设置正确。修改后台路径后必须重新构建并重新部署。

## 3. 创建 D1 和 KV

创建 D1 数据库：

```bash
pnpm exec wrangler d1 create dujiao-next-db
```

创建上传文件使用的 KV：

```bash
pnpm exec wrangler kv namespace create DUJIAO_UPLOADS
```

复制配置模板：

PowerShell：

```powershell
Copy-Item wrangler.example.jsonc wrangler.jsonc
```

Bash：

```bash
cp wrangler.example.jsonc wrangler.jsonc
```

把 Cloudflare 返回的 `database_name`、`database_id` 和 KV `id` 填入 `wrangler.jsonc`。该文件已被 `.gitignore` 忽略，不会被提交。

## 4. 初始化数据库

应用全部迁移：

```bash
pnpm run db:remote
```

新数据库是空的，不包含默认管理员、示例商品、订单或支付渠道。

## 5. 创建首个管理员

管理员密码通过临时环境变量传入，不会写入命令参数或源码。

PowerShell：

```powershell
$env:ADMIN_USERNAME = "your-admin-name"
$env:ADMIN_PASSWORD = "use-a-long-random-password"
pnpm run admin:create:remote
Remove-Item Env:ADMIN_USERNAME
Remove-Item Env:ADMIN_PASSWORD
```

Bash：

```bash
export ADMIN_USERNAME='your-admin-name'
export ADMIN_PASSWORD='use-a-long-random-password'
pnpm run admin:create:remote
unset ADMIN_USERNAME ADMIN_PASSWORD
```

密码至少 12 位。脚本使用 PBKDF2-SHA256（100,000 次迭代）生成哈希，数据库中不会保存明文密码。

## 6. 构建与部署

先验证：

```bash
pnpm run typecheck
pnpm run test:user
pnpm run build
```

部署 Worker：

```bash
pnpm exec wrangler deploy
```

首次部署会得到一个 `workers.dev` 地址。确认可以访问后，再在 Cloudflare Workers 后台添加 Custom Domain；也可以按 Cloudflare 官方说明在 `wrangler.jsonc` 中添加 `routes`。

## 7. 首次上线配置

访问：

```text
https://你的域名/你设置的后台路径/
```

登录后至少完成：

1. 站点设置：名称、正式站点 URL、SEO、时区与币种。
2. 邮件设置：发件地址、域名验证、Resend 或 Cloudflare Email 配置。
3. 人机验证：生产环境建议启用 Cloudflare Turnstile。
4. 支付渠道：配置真实渠道并验证异步通知签名。
5. 商品与库存：创建分类、商品、SKU、人工库存或卡密库存。
6. 法律与客服信息：按经营地区要求填写。

## 8. 本地开发

初始化本地 D1：

```bash
pnpm run db:local
```

创建本地管理员：

```powershell
$env:ADMIN_USERNAME = "local-admin"
$env:ADMIN_PASSWORD = "local-password-at-least-12"
pnpm run admin:create:local
```

启动：

```bash
pnpm run build
pnpm run dev
```

默认地址为 `http://127.0.0.1:8787`。

## 9. 更新与备份

更新代码后执行：

```bash
pnpm install
pnpm run typecheck
pnpm run test:user
pnpm run deploy
```

执行迁移或发布重要版本前，先导出 D1 数据。不要把数据库导出、`.dev.vars`、`wrangler.jsonc` 或任何 API 密钥提交到 Git。

## 10. 常见问题

### 后台显示 404

确认 `config/project.json` 的 `adminPath` 在构建前已经设置，并重新执行 `pnpm run build` 和部署。

### 上传失败

确认 `wrangler.jsonc` 中存在绑定名为 `DUJIAO_UPLOADS` 的 KV，并且 ID 正确。

### 邮件无法发送

先验证发信域名，再检查 API Key、发件地址和 DNS。密钥只在后台配置，不要写入仓库。

### 支付成功但订单未更新

检查支付平台回调地址、签名密钥和 Cloudflare Worker 日志。正式收款前必须使用小额订单完整测试一次同步跳转和异步回调。
