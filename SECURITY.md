# Security Policy / 安全说明

## 中文

- 本仓库不提供默认管理员账号或密码。
- 不要提交 `wrangler.jsonc`、`.dev.vars`、数据库导出、卡密、支付私钥或邮件 API Key。
- 生产环境应启用强密码、管理员两步验证、Cloudflare Turnstile 和最小权限 API Token。
- 支付上线前必须验证服务端回调签名、订单号、金额、币种和幂等处理。
- 发现漏洞时请使用 GitHub Private Vulnerability Reporting 或 Security Advisory 私下报告，不要在公开 Issue 中披露利用细节或真实凭据。

## English

- This repository provides no default administrator username or password.
- Never commit `wrangler.jsonc`, `.dev.vars`, database exports, card secrets, payment private keys, or email API keys.
- Production deployments should use strong passwords, administrator 2FA, Cloudflare Turnstile, and least-privilege API tokens.
- Before accepting payments, verify server-side webhook signatures, order IDs, amounts, currencies, and idempotency.
- Report vulnerabilities privately through GitHub Private Vulnerability Reporting or a Security Advisory. Do not disclose exploit details or real credentials in a public issue.
