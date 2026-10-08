**English** | [繁體中文](03-sources-and-open-questions.zh-TW.md)

# Official Sources and Questions to Resolve Before Launch

Access date: 2026-10-09. References include current official documentation and source code on the main branch. `main` changes over time; pin a release for deployment and retain its LICENSE, NOTICE, configuration, and image digest.

## Source Map

| Source | Information used in this research |
| --- | --- |
| [OpenRouter Terms](https://openrouter.ai/terms) | Updated 2026-08-31; resale restriction, non-transferable credits, application integration, and model terms |
| [OpenRouter Pricing](https://openrouter.ai/pricing) | Standard 5.5%, Business 8%; plan names do not establish resale rights |
| [OpenRouter FAQ](https://openrouter.ai/docs/faq) | Model billing dimensions and top-ups |
| [OpenRouter OAuth](https://openrouter.ai/docs/guides/overview/auth/oauth) | User authorization and user-controlled API keys |
| [OpenRouter Management API](https://openrouter.ai/docs/guides/overview/auth/management-api-keys) | Key management, limits, and administrative credential permissions |
| [OpenRouter Usage Accounting](https://openrouter.ai/docs/cookbook/administration/usage-accounting) | Usage, cost, final streaming data, and generation ID queries |
| [New API Quick Start](https://docs.newapi.pro/en/docs) | Deployment, channel configuration, and platform tokens |
| [New API README](https://github.com/QuantumNous/new-api/blob/main/README.md) | Docker, storage, and HTTPS cookie configuration |
| [New API Compose](https://github.com/QuantumNous/new-api/blob/main/docker-compose.yml) | PostgreSQL, Redis, sample secrets, and networking |
| [New API Channel Documentation](https://docs.newapi.pro/zh/docs/guide/feature-guide/admin/channel) | Model and upstream configuration |
| [New API Channel Source](https://github.com/QuantumNous/new-api/blob/main/constant/channel.go) | OpenRouter channel type and base URL |
| [New API Wallet](https://docs.newapi.pro/zh/docs/guide/feature-guide/user/wallet) | Top-ups, redemption codes, subscriptions, and payment activation requirements |
| [New API LICENSE](https://github.com/QuantumNous/new-api/blob/main/LICENSE) and [NOTICE](https://github.com/QuantumNous/new-api/blob/main/NOTICE) | AGPLv3, specified attribution, and a visible project link |
| [LiteLLM Docker Quickstart](https://docs.litellm.ai/docs/proxy/docker_quick_start) | Containers and virtual key setup |
| [LiteLLM OpenRouter](https://docs.litellm.ai/docs/providers/openrouter) | OpenRouter adapter |
| [LiteLLM Virtual Keys](https://docs.litellm.ai/docs/proxy/virtual_keys) | Key and budget features |
| [LiteLLM LICENSE](https://github.com/BerriAI/litellm/blob/main/LICENSE) | MIT scope and the enterprise exception |
| [Stripe Webhooks](https://docs.stripe.com/webhooks) | Signatures, duplicate events, and event ordering limits |

These official references establish interfaces and requirements, not independent performance or security evaluations. The option ranking compares work that must be added. Effort, hardware, payment fee rates, and margin examples are planning assumptions made in this research.

## Differences Between Licensing Versions

New API's [archived documentation](https://github.com/QuantumNous/new-api-docs/blob/main/docs/wiki/project-introduction.md) described broader branding retention requirements. The current LICENSE and NOTICE differ. Check the licensing files for the selected release. The older description does not establish that every current logo change requires a commercial license, and the current NOTICE's specified attribution requirements must still be observed.

OpenRouter's standard Terms prohibit resale, while its Management API describes key management per SaaS customer. Both can hold: a documented administrative capability does not authorize every business model using it. Obtain a written response and applicable agreement covering the specific product.

## Business Questions to Resolve

| Question | Effect on the plan |
| --- | --- |
| Are customers purchasing general API access or specific application features? | Determines upstream resale authorization and product design |
| Where are the operating entity and customers located, and which models are targeted? | Determines payment eligibility and model service scope |
| What are average usage per customer, payment size, and payment frequency? | Determines markup, fixed service fees, and minimum top-ups |
| Are closed-source modifications or removal of specified attribution required? | Determines the New API or LiteLLM licensing strategy |
| Which clients and endpoints do the first customers need? | Determines compatibility acceptance and effort |
| Is there written upstream resale authorization and an allocation of responsibilities? | Determines whether public sales are permitted and how customer terms are written |

## Draft Inquiry for OpenRouter

The following draft can be submitted by the operator. It has not been sent.

> We are evaluating a VPS-hosted platform where customers register, purchase service credits, receive our platform API keys, and call selected models through an OpenAI-compatible endpoint. Our backend would use an OpenRouter organization account, meter usage, and charge customers our published rates.
>
> We understand that Section 7.4 of the current Terms prohibits resale of API access. Do you offer a separate agreement that explicitly permits this model? If so, please clarify covered models, customer territories, downstream terms, usage and abuse responsibilities, data processing obligations, key-management requirements, pricing, and termination arrangements.
>
> Please also distinguish this arrangement from embedding OpenRouter in a value-added application, and from an application where each customer connects their own OpenRouter account through OAuth and pays you directly for model usage. We would like to confirm the permitted scope before enabling public sales.

Record the selected version, licensing files, models with verified prices, payment requirements, and acceptance results in subsequent deployment decisions. If a resale agreement is unavailable, retain two alternatives: an upstream service with suitable authorization, or an application where customers bring their own keys. Choose according to the product being sold.
