# User Guide

## Admin access

The admin URL is controlled by `adminPath` in `config/project.json`. There is no default account; create the first administrator with the setup script described in the deployment guide.

Enable administrator two-factor authentication after the first login and store recovery codes offline.

## Store settings

Configure the following in the admin panel:

- Store name, logo, icon, and final public URL
- SEO title, keywords, and description
- Default language, currency, and timezone
- Home announcement, page content, and template
- Email, verification-code, and order-notification policies
- Cloudflare Turnstile

The public URL is used in email links, callbacks, and reseller-site detection, so it must match the production origin.

## Products and inventory

Recommended order:

1. Create a category.
2. Create a product with localized names, descriptions, and rich content.
3. Add one or more SKUs with sale and cost prices.
4. Select manual or automatic fulfillment.
5. Configure stock display, purchase limits, and wholesale tiers.
6. Complete a test order before publishing the product.

Manual products use the SKU manual-stock counters. Automatic products require imported card secrets; available secrets are the sellable inventory. Order creation, locking, payment, and fulfillment update locked, sold, and available quantities.

## Manual fulfillment

A product may collect fields such as contact details, account information, recipient name, and address. Submitted values are stored with the order snapshot.

After payment, a manual order moves into processing. The administrator enters delivery or shipping information, delivers the order, and later marks it completed. Do not place internal notes in customer-visible delivery content.

## Automatic fulfillment

Create a card-secret batch, bind it to a product and SKU, and import the secrets. Only available and unlocked secrets can be assigned.

Before launch, test:

- Single and multiple quantities
- Concurrent checkout of the final item
- Stock release after payment expiry
- Idempotent duplicate payment callbacks
- Copying delivery content from the customer order page

## Payment channels

Select the provider and configure merchant credentials in the admin panel. Never put payment secrets in source files.

Test each channel for payment creation, browser return, server webhook, duplicate webhook, amount validation, expiry, and refunds. Treat an order as paid only after a valid server notification with a matching order number, amount, and currency.

## Email

Resend and Cloudflare Email can be configured from the admin panel. Verify the sender domain, add the sender and API key, and use the test-send function.

For production, send order emails only for meaningful state changes such as delivered, completed, or refunded. Apply rate limits and attempt limits to verification-code emails.

## Order states

- Pending payment: created but not confirmed as paid.
- Paid: payment confirmed, processing not started.
- Fulfilling: manual fulfillment or procurement is in progress.
- Partially delivered: only some child orders are delivered.
- Delivered: delivery or shipping information has been submitted.
- Completed: the order workflow is closed.
- Canceled: the order is canceled and locked resources are released.
- Refunded / partially refunded: a refund has been processed.

Do not edit order states directly in D1. Use admin operations so inventory, wallet, card-secret, and notification side effects remain consistent.

## Members and guest orders

Members may access only their own orders. Guests must keep the order number, lookup email, and order password. Never post guest lookup credentials in public pages or support groups.

## Operations

- Export D1 regularly and test restoration.
- Review Worker errors, failed payments, and failed email deliveries.
- Never commit API keys, payment keys, card secrets, or database backups.
- Back up before updates; run migrations, tests, and a low-value payment test afterward.
- Rotate administrator passwords and audit administrator roles regularly.
