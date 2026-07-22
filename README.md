# Dujiao Next for Cloudflare

[中文](#中文) | [English](#english)

## 中文

基于 Dujiao Next 的 Cloudflare 原生适配版本。项目保留原有 Vue 前台与管理后台，并将后端能力迁移到 Cloudflare Workers、D1 和 KV，无需单独购买 VPS。

原版项目仓库：[dujiao-next/dujiao-next](https://github.com/dujiao-next/dujiao-next)

> 本项目由 ChatGPT / Codex 辅助完成 Cloudflare 适配与代码重构，是社区维护的非官方移植版本，与 Dujiao Next 官方无隶属关系。部分实现可能与原版存在差异。

### 功能

- 商品分类、多规格 SKU、上下架与多语言内容
- 人工交付、自动卡密交付与库存锁定
- 会员、游客订单、钱包、礼品卡与优惠券
- 批发价、会员价、活动价与成本利润统计
- 支付渠道、退款、订单状态与幂等处理
- Resend / Cloudflare Email 邮件通知与验证码
- Cloudflare Turnstile、人机验证与管理员两步验证
- 分销商、推广佣金、上下游站点与商品同步
- 富文本内容、首页公告、博客、SEO 和多套前台模板

### 架构

| 模块 | 技术 |
| --- | --- |
| 用户前台 | Vue 3 + Vite + TypeScript |
| 管理后台 | Vue 3 + Vite + TypeScript |
| API | Cloudflare Workers |
| 数据库 | Cloudflare D1 |
| 上传文件 | Cloudflare KV |
| 静态资源 | Cloudflare Workers Assets |

### 快速开始

```bash
pnpm install
pnpm run typecheck
pnpm run test:user
pnpm run build
```

部署前编辑 [`config/project.json`](config/project.json)，设置站点地址与后台路径；随后创建 Cloudflare D1、KV，并根据 [`wrangler.example.jsonc`](wrangler.example.jsonc) 完成资源绑定。

详细步骤：

- [中文部署说明](docs/DEPLOYMENT.zh-CN.md)
- [中文使用说明](docs/USAGE.zh-CN.md)

默认后台路径为 `/admin-panel/`，建议在首次构建前修改。

## English

A Cloudflare-native port of Dujiao Next. It keeps the original Vue storefront and admin application while moving backend services to Cloudflare Workers, D1, and KV, so no separate VPS is required.

Upstream repository: [dujiao-next/dujiao-next](https://github.com/dujiao-next/dujiao-next)

> This is an unofficial, community-maintained port adapted and refactored for Cloudflare with assistance from ChatGPT / Codex. It is not affiliated with the Dujiao Next maintainers, and some implementations may differ from upstream.

### Features

- Product categories, multi-SKU products, localization, and publishing controls
- Manual fulfillment, automatic card-secret delivery, and inventory locking
- Member and guest orders, wallet, gift cards, and coupons
- Wholesale, member, campaign pricing, cost, and profit reporting
- Payment channels, refunds, order states, and idempotent processing
- Resend / Cloudflare Email notifications and verification codes
- Cloudflare Turnstile, risk controls, and administrator 2FA
- Resellers, affiliate commissions, upstream sites, and product synchronization
- Rich content, home announcements, blog, SEO, and storefront templates

### Architecture

| Component | Technology |
| --- | --- |
| Storefront | Vue 3 + Vite + TypeScript |
| Admin | Vue 3 + Vite + TypeScript |
| API | Cloudflare Workers |
| Database | Cloudflare D1 |
| Uploads | Cloudflare KV |
| Static assets | Cloudflare Workers Assets |

### Quick start

```bash
pnpm install
pnpm run typecheck
pnpm run test:user
pnpm run build
```

Before deployment, edit [`config/project.json`](config/project.json) to set the public URL and admin path. Then create Cloudflare D1 and KV resources and fill in the bindings from [`wrangler.example.jsonc`](wrangler.example.jsonc).

Full guides:

- [English deployment guide](docs/DEPLOYMENT.en.md)
- [English user guide](docs/USAGE.en.md)

The default admin path is `/admin-panel/`; change it before the first production build.

## License

This project includes code derived from Dujiao Next and is distributed under the GNU Affero General Public License v3.0. See [LICENSE](LICENSE).
