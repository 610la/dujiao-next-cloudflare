# Dujiao Next for Cloudflare

[中文](#中文) | [English](#english)

## 中文

这是 Dujiao Next 的 Cloudflare 适配版：前台与后台沿用 Dujiao Next Vue 应用，后端 API 改写为 Cloudflare Workers，并使用 D1 保存业务数据、KV 保存上传文件。

仓库是干净源码模板，不包含站点域名、Cloudflare 资源 ID、管理员账号、商品、订单、卡密、支付参数、邮件密钥或任何线上数据。首次部署后需要自行创建管理员并完成业务配置。

### 文档

- [中文部署说明](docs/DEPLOYMENT.zh-CN.md)
- [中文使用说明](docs/USAGE.zh-CN.md)
- [English deployment guide](docs/DEPLOYMENT.en.md)
- [English user guide](docs/USAGE.en.md)
- [安全说明](SECURITY.md)

### 技术栈

- Cloudflare Workers + Assets
- Cloudflare D1
- Cloudflare KV
- Vue 3 + Vite + TypeScript
- pnpm workspace

### 快速检查

```bash
pnpm install
pnpm run typecheck
pnpm run test:user
pnpm run build
```

默认后台路径是 `/admin-panel/`，由 [`config/project.json`](config/project.json) 统一控制。正式部署前建议改成仅管理员知道的路径。

## English

This project ports Dujiao Next to Cloudflare. The original Vue storefront and admin applications are retained, while the backend API is implemented with Cloudflare Workers, D1, and KV.

The repository is a clean source template. It contains no production domain, Cloudflare resource ID, administrator account, product, order, card secret, payment credential, email key, or live data. Create the first administrator and configure the store after deployment.

### Documentation

- [Chinese deployment guide](docs/DEPLOYMENT.zh-CN.md)
- [Chinese user guide](docs/USAGE.zh-CN.md)
- [English deployment guide](docs/DEPLOYMENT.en.md)
- [English user guide](docs/USAGE.en.md)
- [Security policy](SECURITY.md)

### Stack

- Cloudflare Workers + Assets
- Cloudflare D1
- Cloudflare KV
- Vue 3 + Vite + TypeScript
- pnpm workspace

### Quick verification

```bash
pnpm install
pnpm run typecheck
pnpm run test:user
pnpm run build
```

The default admin path is `/admin-panel/`. It is controlled by [`config/project.json`](config/project.json); change it before a production deployment.

## License

This repository includes code derived from Dujiao Next. It is distributed under the GNU Affero General Public License v3.0. See [LICENSE](LICENSE).
