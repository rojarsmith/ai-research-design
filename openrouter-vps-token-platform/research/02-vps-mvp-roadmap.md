**English** | [繁體中文](02-vps-mvp-roadmap.zh-TW.md)

# VPS Deployment Roadmap and Acceptance for a Minimum Platform

Research date: 2026-10-09. This roadmap uses New API as the fastest technical starting point. Public API resale requires appropriate upstream authorization. Before obtaining it, validate the technology with a mock upstream service or internal uses allowed by the Terms. A closed trial is not an exemption from the resale restriction.

## Single VPS Architecture

| Component | Responsibility | Suggested starting configuration |
| --- | --- | --- |
| Linux VPS | Run the proxy and data services | Start trials with 2 vCPU, 4 GB RAM, and about 40 GB SSD; adjust to measured load |
| HTTPS reverse proxy | TLS, request size limits, and streaming forwarding | Caddy or an existing Nginx setup; verify that SSE is not buffered |
| New API | Accounts, platform keys, model restrictions, credits, and administration | One container with a pinned version |
| PostgreSQL | Users, credits, orders, and usage data | Persistent storage; do not expose the database port publicly |
| Redis | Cache and rate limiting | Private network access with authentication |
| Upstream model API | Inference and upstream costs | Keys only in backend channels, with spending limits |
| Off-host backups and monitoring | Recovery, usage alerts, and availability alerts | Back up ledger data, configuration, and secrets required for recovery |

These specifications are an engineering starting estimate, not official minimum requirements or a concurrency guarantee. Major loads come from long-lived connections, write frequency, logs, and traffic. Test SSE connections rather than relying only on short requests per second. A single VPS remains a single point of failure suitable for early validation.

The official Compose example uses New API, PostgreSQL, and Redis, with sample passwords, `latest` images, and an exposed port 3000. For deployment, use pinned versions or digests, random secrets, and restricted network exposure. [Official Compose](https://github.com/QuantumNous/new-api/blob/main/docker-compose.yml)

## Day One Internal Demo

1. Check LICENSE, NOTICE, and payment feature requirements for the selected release. Record the version and image digest.
2. Obtain the source through the official workflow, edit Compose, and start the services. Use PostgreSQL and Redis. A single SQLite container can evaluate local features; use the database deployment for an ongoing paid platform.
3. Configure domain DNS and HTTPS. If the proxy runs on the host, bind the application port only to `127.0.0.1`. If the proxy shares the Docker network, no public application port is needed. Initialize the administrator and restrict administrative access.
4. Generate and retain a stable `SESSION_SECRET`. For HTTPS, configure `SESSION_COOKIE_SECURE=true` and an exact `SESSION_COOKIE_TRUSTED_URL`. Replace every database and Redis sample password.
5. Add an OpenRouter channel and configure its upstream key only in the administration console. Prefer the dedicated channel type's default URL. Its base and final `/v1` path are combined by the adapter; do not append `/v1` twice.
6. Choose currently available model IDs, create a test user and platform key with a small budget, and complete one non-streaming call and one SSE call.

Deployment and cookie configuration: [Official README](https://github.com/QuantumNous/new-api/blob/main/README.md). Channel and model configuration: [Channel Documentation](https://docs.newapi.pro/zh/docs/guide/feature-guide/admin/channel), [OpenRouter Channel Source](https://github.com/QuantumNous/new-api/blob/main/constant/channel.go).

## First Release Scope

Include login, key creation and revocation, 3–5 text models, balance queries, usage records, administrator suspension, and upstream balance alerts. Set account concurrency limits, output caps, key budgets, and a platform daily spending cap. New customers should start with lower limits.

Do not start with unlimited plans. Add image, audio, video, long-running tasks, Responses, and other interfaces individually, checking compatibility and billing for each. “OpenAI-compatible” alone does not establish support for every client or endpoint.

## Closed Trial in Three to Seven Days

Where the upstream use is permitted, invite approximately 5–20 testers and initially restrict expensive models and the maximum cost per request. Use test credits before collecting real payments. Manual payment confirmation and credit adjustments apply only to trial operations with appropriate authorization and payment arrangements; record both payment and credit events.

Keep the platform's own price table and effective dates. If New API calculates retail charges using multipliers and tokens, separately reconcile customer deductions, upstream reported costs, and upstream account deductions. Estimates can limit requests before execution, but cannot be used directly as final costs.

OpenRouter's current usage documentation describes usage in non-streaming responses and in the last SSE message for streaming responses, including cost, token counts, reasoning, and available cache information. Generation IDs also support asynchronous queries. Verify fields and currency on the selected endpoint before connecting them to billing. [Usage Accounting](https://openrouter.ai/docs/cookbook/administration/usage-accounting)

The intended credit workflow is to reserve an estimated amount, settle under the retail pricing rules after completion, and release the difference. Verify the selected New API release's behavior under concurrency, streaming interruption, retries, and batch updates. Add restrictions or improve billing before expanding paid usage if it does not satisfy the requirements.

## Self Service Payments in One to Two Weeks

New API supports several payment integrations, but availability depends on configuration and the release's payment compliance status. Confirm the operating entity's location, the product being sold, and the payment provider's supported scope before choosing a provider. Stripe integration in the software does not establish eligibility for your entity. [New API Wallet](https://docs.newapi.pro/zh/docs/guide/feature-guide/user/wallet)

For a Stripe-style callback, verify the signature and deduplicate by payment object and order. In one database transaction, mark the order paid, add credits, and create the ledger record. Returning to a payment success page must not trigger crediting by itself. Stripe documents duplicate events and events arriving out of order, so handle duplicate and delayed callbacks. [Stripe Webhooks](https://docs.stripe.com/webhooks)

Run acceptance checks even when using an existing payment module; a successful payment test is insufficient. Refunds and chargebacks require their own states and records. Platform policies must explain treatment of consumed services and unused credits. Upstream refund policies do not automatically determine obligations to your customers.

## Minimum Acceptance Cases

| Case | Passing condition |
| --- | --- |
| Insufficient balance or revoked key | Reject new requests without creating new upstream costs |
| Concurrent requests from one account | Atomic reservation or another verified restriction prevents repeated spending of the same balance; overspend exposure has a defined bound |
| Normal SSE and customer disconnect | Release connections and reservations; incurred upstream costs can be settled or traced, without assuming no cost because text was not received |
| Upstream timeout after possible processing | Record a pending reconciliation state; do not blindly retry paid requests |
| Retries configured in both gateway and upstream | Attempts are bounded and each upstream attempt can be distinguished from a single customer charge |
| Missing usage or unknown retail price | Disable unknown models or mark pending settlement rather than charging as though cost were zero |
| Duplicate, delayed, or out-of-order payment callbacks | Credit each payment once, including after a restart; orders remain traceable |
| Refund or chargeback | Traceable adjustment records keep balances consistent with payment states |
| Database or Redis failure | Reject new paid requests when billing state is uncertain; reconcile after recovery |
| Restore from an off-host backup | Recover users, key states, balances, orders, and usage without duplicate crediting |

Daily reconciliation has two parts. Customer balances must satisfy `opening credits + payment credits + adjustments − retail deductions = closing credits`. Upstream costs must reconcile the sum of actual request costs against changes in upstream account usage deductions, listing top-ups and fees separately. Explain differences; simply subtracting upstream costs from retail charges is not reconciliation.

## Expansion Triggers

When active SSE connections, database writes, or backup windows affect service, measure and address the bottleneck before separating the database or adding proxy nodes. Keep upstream keys and management APIs in restricted backend services. Generate the public model catalog from the platform's allowlist so customers cannot select unknown expensive models or arbitrary upstream parameters.

The technical platform can be built first. Public payment collection depends on upstream written authorization, payment provider eligibility, licensing for the selected release, and the acceptance checks above. Running containers alone is not the completion criterion.
