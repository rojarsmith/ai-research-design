**English** | [繁體中文](README.zh-TW.md)

# Rapid Deployment Research for an OpenRouter Usage Platform on a VPS

Research date: 2026-10-09 (Asia/Taipei).

For a platform where customers register, top up a balance, receive a platform API key, and pay according to model usage, **New API is the closest to a ready-made starting point among the options compared here**. A single Linux VPS with Docker Compose, a limited model catalog, and a small customer group can reduce the work needed to build accounts, wallets, and an administration console.

However, **Section 7.4 of OpenRouter's current Terms explicitly prohibits reselling API access to models**. A standard account does not provide resale authorization. Obtain a separate written agreement explicitly covering this business model, or use an upstream service that permits it. To validate a product first, consider an AI application where customers connect their own OpenRouter keys. Section 5's description of application integration does not automatically override the resale restriction. [OpenRouter Terms](https://openrouter.ai/terms)

## Recommended Options

| Need | Starting point | Main remaining work |
| --- | --- | --- |
| Build accounts and usage credits quickly | New API | Upstream authorization, model price verification, payment configuration, reconciliation, and deployment acceptance |
| Own branded frontend and complex routing | LiteLLM with custom account and billing services | Top-up orders, payment callbacks, duplicate prevention, refunds, and a ledger |
| Validate an application before obtaining API resale authorization | Own AI application with OpenRouter OAuth | Users pay OpenRouter for usage; the platform charges for application services and must still comply with applicable terms |

New API documents top-ups and subscriptions; LiteLLM provides virtual keys, budgets, and usage management; OpenRouter OAuth produces user-controlled keys. These establish technical capabilities. Commercial suitability depends on the actual product and its authorization. [New API Wallet](https://docs.newapi.pro/zh/docs/guide/feature-guide/user/wallet), [LiteLLM Virtual Keys](https://docs.litellm.ai/docs/proxy/virtual_keys), [OpenRouter OAuth](https://openrouter.ai/docs/guides/overview/auth/oauth)

## Documents

- [Feasibility and cost comparison](research/01-feasibility-and-options.md): business models, tool capabilities, licenses, margins, and selection rationale.
- [VPS deployment roadmap and acceptance](research/02-vps-mvp-roadmap.md): deployment steps, minimum product scope, effort estimates, billing checks, and failure scenarios.
- [Sources and open questions](research/03-sources-and-open-questions.md): official references, version differences, and a draft inquiry for OpenRouter.

Effort estimates, VPS specifications, and cost examples are planning assumptions. This directory contains research documents; no service has been deployed and no paid API calls have been made.
