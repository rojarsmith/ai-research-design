**English** | [繁體中文](01-feasibility-and-options.zh-TW.md)

# Feasibility and Rapid Build Options for an OpenRouter Usage Platform

Research date: 2026-10-09. The assumed product is an API usage platform: customers register, obtain keys, purchase platform credits, and use an OpenAI-compatible interface. The VPS handles authentication, proxying, and billing. Upstream services perform inference, so this architecture does not require a GPU on the VPS.

New API requires the least custom development among these options. Choose LiteLLM when you need to design your own product interface and billing services. Upstream authorization and correct charging determine whether public sales are viable; starting containers is only one part of the work.

## Product and Authorization Scope

Distinguish three meanings of “token”: an API key is an access credential, model tokens measure usage, and platform credits represent the services customers purchase. Models have different input, output, cache, and other charges. One million tokens across all models cannot be treated as a single interchangeable product. [OpenRouter Billing FAQ](https://openrouter.ai/docs/faq)

| Business model | Assessment and possible route |
| --- | --- |
| Share the platform's upstream account and sell platform API keys and credits | The resale model evaluated here; prohibited by the current standard Terms, requiring a separate agreement or another upstream service |
| Transfer OpenRouter credits or account credentials to customers | Credits are non-transferable; do not structure the product this way |
| Integrate models into an application, such as document processing or customer support | The Terms describe this scenario, but model terms still apply and the product must be checked against the API resale prohibition |
| Customers bring their own OpenRouter keys and the platform provides application features | Consider OAuth integration; customers pay for model usage and the platform charges for application services, without claiming a general resale exemption |

This assessment uses Sections 4.4, 5, and 7 of the Terms updated on 2026-08-31. Purchasing a Business or Enterprise plan does not establish resale rights merely through the plan name. [OpenRouter Terms](https://openrouter.ai/terms)

OpenRouter's Management API can create, update, and disable keys and apply usage limits. These are administrative capabilities, not resale permission, customer payment collection, or a platform wallet ledger. Management keys cannot call completion endpoints and have broad permissions; keep them only in an administrative service. [Management API](https://openrouter.ai/docs/guides/overview/auth/management-api-keys)

## Three Rapid Build Routes

The following effort estimates assume one engineer familiar with Docker, web development, and APIs, with a VPS, domain, and necessary accounts already available. They exclude upstream contracting, payment provider approval, and custom legal documents. Verify feature availability in the selected release through acceptance checks.

| Route | Reusable capabilities | Custom work | Estimated technical effort | Best fit |
| --- | --- | --- | --- | --- |
| New API | Accounts, keys, model restrictions, credits, wallet, and usage records | Price calibration, payment setup and acceptance, operating rules | Internal demo: half a day to 1 day; small closed trial: 3–7 days; self-service payments: about 1–2 weeks | Quickly validate an API usage platform |
| LiteLLM with a custom portal | OpenRouter adapter, virtual keys, budgets, and usage tracking | Customer storefront, orders, top-up ledger, payments, and refunds | Gateway: about 1 day; minimum product with billing: about 1–3 weeks | Custom frontend and routing across upstream services |
| Own application with OpenRouter OAuth | User-controlled keys obtained through authorization | Application features, login, key custody, and service fee collection | Single-feature prototype: about 1–3 days; paid product depends on added features | Validate application value while reducing the need to fund customers' model usage |

New API documents deployment, channels, and tokens; LiteLLM provides Docker deployment and an OpenRouter adapter; OAuth documents exchanging an authorization code for a user-controlled key. [New API Quick Start](https://docs.newapi.pro/en/docs), [LiteLLM Deployment](https://docs.litellm.ai/docs/proxy/docker_quick_start), [LiteLLM OpenRouter Adapter](https://docs.litellm.ai/docs/providers/openrouter), [OpenRouter OAuth](https://openrouter.ai/docs/guides/overview/auth/oauth)

## Why New API Is Faster

The current channel source includes an OpenRouter type and default upstream URL. The wallet documentation covers top-ups, redemption codes, subscriptions, and payment integrations including Stripe. These reduce custom development, but payment features require complete configuration and the release's payment compliance status to be satisfied. Installation alone does not mean payments can immediately be collected. [Channel Source](https://github.com/QuantumNous/new-api/blob/main/constant/channel.go), [Wallet Features](https://docs.newapi.pro/zh/docs/guide/feature-guide/user/wallet)

Keep the existing interface and attribution for the first trial, and enable only a few models with verified prices. Adding a custom UI, reseller commissions, unlimited monthly plans, and multiple model endpoint types together would expand the billing verification work.

New API's current LICENSE is AGPLv3. Offering a modified version as a network service involves obligations to provide corresponding source code to users. Its NOTICE also requires modified versions to retain specified attribution and a visible link to the original project. Obtain suitable authorization first if you need closed-source modifications or different licensing terms. [LICENSE](https://github.com/QuantumNous/new-api/blob/main/LICENSE), [NOTICE](https://github.com/QuantumNous/new-api/blob/main/NOTICE)

## When LiteLLM Is Worth Choosing

LiteLLM can serve as the gateway when you want your own brand, routing, and customer interface. Virtual keys and budgets are reusable, but cost tracking is not a customer's prepaid balance. Top-ups, charges, orders, and refunds still need a consistent billing design. [LiteLLM Virtual Keys](https://docs.litellm.ai/docs/proxy/virtual_keys)

The main LICENSE applies MIT to content outside the enterprise directory; the enterprise directory has separate licensing. Check whether selected features require the commercial edition rather than assuming every administration feature is free. [LiteLLM LICENSE](https://github.com/BerriAI/litellm/blob/main/LICENSE)

With OpenRouter as the only upstream service, another LiteLLM layer mainly adds tenant management, observability, and a path to future upstream changes. If those capabilities are not yet needed, an application can call OpenRouter directly and reduce the number of services to operate. This is an architectural tradeoff, not a measured performance result.

## Pricing and Cost Example

Sell service credits denominated in money, publish model rates and platform service fees, and retain detailed token usage and costs internally. The current listed platform fees are 5.5% for Standard and 8% for Business, with negotiated Enterprise pricing. Calculate model charges and platform fees separately, using the actual plan and payment page. [OpenRouter Pricing](https://openrouter.ai/pricing)

The following hypothetical scenario assumes appropriate resale authorization; it is not a quote. Monthly model usage has a US$1,000 cost baseline, and all credits sold are consumed during the month. Assume a 5.5% upstream fee based on Standard, customer payment processing at 3.5% of revenue plus US$0.30 per transaction, 100 payments, and US$50 for the VPS, backups, and monitoring. Minimum transaction fees, taxes, exchange differences, refunds, chargebacks, license costs, and labor are excluded.

| Markup on model usage baseline | Customer revenue | Upstream spending | Customer payment fees | Fixed costs | Amount remaining after these costs |
| --- | ---: | ---: | ---: | ---: | ---: |
| 10% | US$1,100 | US$1,055 | US$68.50 | US$50 | −US$73.50 |
| 20% | US$1,200 | US$1,055 | US$72.00 | US$50 | US$23.00 |
| 30% | US$1,300 | US$1,055 | US$75.50 | US$50 | US$119.50 |

The calculation is: `remaining amount = customer revenue − model baseline × (1 + upstream fee rate) − customer revenue × payment fee rate − payment count × fixed transaction fee − platform fixed costs`. This scenario needs approximately 17.6% markup to cover the listed costs. A 20% markup is not a 20% profit margin.

Credits purchased but not yet consumed should not be treated directly as realized gross profit; retain funds for service delivery and refunds. A fixed service fee for low-usage customers can reduce dependence on token markup to cover support costs. Replace these assumptions with actual payment costs and usage per customer before setting prices.

## Recommended Adoption Order

1. Decide whether the product sells API access or application features, and confirm the upstream service's permitted scope.
2. With appropriate upstream authorization, use New API's existing interface for a closed trial.
3. Start with text Chat Completions and 3–5 models with verified prices.
4. Complete streaming, concurrency, payment, and reconciliation acceptance checks before opening self-service top-ups.
5. Consider LiteLLM with a custom frontend once customers demonstrate a need for a branded portal or specialized billing.
