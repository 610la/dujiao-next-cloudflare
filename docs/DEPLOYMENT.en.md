# Cloudflare Deployment Guide

## 1. Prerequisites

You need:

- A Cloudflare account
- Node.js 22 or later
- pnpm 10 or later
- A domain using Cloudflare DNS if you want a custom domain

Install dependencies and authenticate Wrangler:

```bash
pnpm install
pnpm exec wrangler login
```

## 2. Configure public project values

Edit `config/project.json`:

```json
{
  "adminPath": "change-this-admin-path",
  "siteUrl": "https://shop.example.com"
}
```

- `adminPath` accepts letters, numbers, hyphens, and underscores.
- `siteUrl` is the final public origin without a trailing slash.

These values are not credentials, but they must be correct before the first build. Rebuild and redeploy after changing the admin path.

## 3. Create D1 and KV resources

```bash
pnpm exec wrangler d1 create dujiao-next-db
pnpm exec wrangler kv namespace create DUJIAO_UPLOADS
```

Copy the Wrangler template:

PowerShell:

```powershell
Copy-Item wrangler.example.jsonc wrangler.jsonc
```

Bash:

```bash
cp wrangler.example.jsonc wrangler.jsonc
```

Put the returned D1 `database_name`, D1 `database_id`, and KV `id` into `wrangler.jsonc`. The file is ignored by Git.

## 4. Initialize the database

```bash
pnpm run db:remote
```

The new database contains no default administrator, sample product, order, or payment channel.

## 5. Create the first administrator

Credentials are read from temporary environment variables, so the password is not included in source files or command arguments.

PowerShell:

```powershell
$env:ADMIN_USERNAME = "your-admin-name"
$env:ADMIN_PASSWORD = "use-a-long-random-password"
pnpm run admin:create:remote
Remove-Item Env:ADMIN_USERNAME
Remove-Item Env:ADMIN_PASSWORD
```

Bash:

```bash
export ADMIN_USERNAME='your-admin-name'
export ADMIN_PASSWORD='use-a-long-random-password'
pnpm run admin:create:remote
unset ADMIN_USERNAME ADMIN_PASSWORD
```

The password must be at least 12 characters. The script stores a PBKDF2-SHA256 hash with 100,000 iterations, never the plaintext password.

## 6. Build and deploy

```bash
pnpm run typecheck
pnpm run test:user
pnpm run build
pnpm exec wrangler deploy
```

The first deployment receives a `workers.dev` URL. After verification, add a Custom Domain in the Cloudflare Workers dashboard, or add `routes` to `wrangler.jsonc` according to the Cloudflare documentation.

## 7. First production setup

Open:

```text
https://your-domain/your-admin-path/
```

Complete at least the following before accepting orders:

1. Store name, final site URL, SEO, timezone, and currency.
2. Sender domain and Resend or Cloudflare Email configuration.
3. Cloudflare Turnstile for production traffic.
4. A real payment channel with verified webhook signatures.
5. Categories, products, SKUs, and manual or card-secret inventory.
6. Legal and customer-support information required in your region.

## 8. Local development

```bash
pnpm run db:local
pnpm run build
pnpm run dev
```

Create a local administrator with the same environment variables and run:

```bash
pnpm run admin:create:local
```

The default local address is `http://127.0.0.1:8787`.

## 9. Updates and backups

Before important migrations or releases, export the D1 database. After pulling updates:

```bash
pnpm install
pnpm run typecheck
pnpm run test:user
pnpm run deploy
```

Never commit database exports, `.dev.vars`, `wrangler.jsonc`, or API credentials.

## 10. Troubleshooting

### The admin page returns 404

Make sure `adminPath` was set before the build, then rebuild and redeploy.

### Uploads fail

Verify that `wrangler.jsonc` contains a KV binding named `DUJIAO_UPLOADS` with the correct namespace ID.

### Email cannot be sent

Verify the sender domain, sender address, API key, and DNS records. Configure secrets only in the admin UI.

### A paid order is not updated

Check the provider callback URL, signing secret, and Worker logs. Complete an end-to-end low-value payment test before accepting real payments.
