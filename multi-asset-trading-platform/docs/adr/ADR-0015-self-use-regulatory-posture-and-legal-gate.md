**English** | [繁體中文](ADR-0015-self-use-regulatory-posture-and-legal-gate.zh-TW.md)

# ADR-0015: "Self-directed software" regulatory posture, with a legal gate before any external user

## Status

**Proposed** · 2026-10-05 · Scope: all scenarios. This is engineering policy, not legal advice; counsel must confirm every point before trigger T1 is acted on.

## Context and problem statement

Whether the platform is ever offered to other people is undecided. The regulatory line is crossed by *activities*, not by architecture ([08](../../research/08-risk-security-ops-compliance.md), [11](../../research/11-taiwan-market-localization.md)), and it is easy to cross by accident: a free signals channel that turns paid crosses it. What posture does the platform take now, and what must happen before anyone other than the owner uses it?

What the research found (not legal advice):

- **Self-use is mostly governed by broker rules.**
  - US: FINRA intraday margin replaced the PDT rule on 2026-06-04, with a broker phase-in allowed until 2027-10-20.
  - Taiwan: API orders count as electronic trading under signed risk disclosures, with a CA certificate. Brokers keep raw orders and IP addresses, and **third parties may not be authorized**.
- **Serving others needs licences.**
  - Taiwan: unlicensed paid securities advice is punishable under SITCA Act Art. 107 (up to 5 years and NT$1M–50M). Unlicensed futures advice falls under Futures Trading Act Art. 112 (up to 7 years). Discretionary management needs separate approval.
  - US: RIA, CTA or broker-dealer registration, depending on the activity.
  - EU: MiCA CASP authorization (the transition ended 2026-07-01).
- **Crypto in Taiwan.** AML registration is required today, and unregistered offshore venues may not solicit Taiwan users. The **Virtual Asset Service Act** passed on 2026-06-30; it takes effect in Q1 2027 at the earliest, with first licences expected around Q1 2028. The domestic Travel Rule applies from October 2026.
- **Market data.** Showing data to anyone else is redistribution. TWSE charges NT$60,000 per month plus internet fees, TAIFEX requires written consent, and IBKR forbids redistributing TWS API data without approval. Our retail data plans are individual-use.
- **Certificates.** Taiwan broker certificates are personal. A customer-hosted edge connector *might* fit broker terms, but that is a legal hypothesis that needs counsel and broker confirmation ([evaluation](../../architecture/evaluation.md), concern 23).
- **IBKR** offers third-party vendors only OAuth 1.0a, after a compliance review, and expects automated-trading vendors to hold the relevant registrations.

## Decision drivers

- Avoid criminal and civil exposure from accidental advisory, management or data-redistribution activity.
- Keep the engineering seams that make a later service possible, without claiming legal positions we have not verified.
- Give one clear, observable trigger for when legal work must start.
- Keep the scenario-1 build free of compliance overhead that self-use does not need.

## Considered options

1. **Self-directed software for the owner's own accounts only, with a mandatory legal gate (trigger T1) before any second user**, and the cheap seams built now.
2. **Design for a licensed service from day one** (Proposal C's tenancy, entitlements and OIDC up front).
3. **No explicit posture**, deciding when a user asks.

## Decision outcome

**Chosen option: 1.** It costs almost nothing in scenario 1, prevents the accidental crossings that carry the worst penalties, and keeps the evolution path open through seams rather than premature platform work.

### Posture (scenario 1)

- The platform is **self-directed software** that trades **only the owner's own accounts**, with the owner's own credentials.
- **Out of scope:** market making; sub-10 ms strategies; custody of anyone else's assets; selling signals (paid or free channels that could become paid); copy trading; managing other people's money; showing licensed market data to anyone else.
- Crypto venues sit on a **configured allow-list** tied to the FSC register (and later to VASP Act licensing). Venue eligibility is configuration, not code. Before any perpetual or options venue becomes a first-live candidate, Phase 0 checks it against the FSC AML-registration list and the venue's own geo terms; if none is eligible, IBKR is the first live market.
- Data use follows the licence registry and `license_tag` ([ADR-0009](ADR-0009-open-source-licensing-strategy.md)). Any professional-status change (for example trading through a company entity) triggers a data-plan review. Sending licensed data to a third-party LLM API is also a use that the registry must allow (`llm_export_allowed`, [ADR-0017](ADR-0017-ai-trust-boundary.md)).
- The tax-lot engine is a pluggable, per-jurisdiction module ([ADR-0016](ADR-0016-multi-currency-books-tax-lots-and-tax-plugins.md)). US wash-sale tracking matters only to US taxpayers; a Taiwan resident gets the Taiwan-resident plug-in. Its reports are bookkeeping aids, not tax advice.

### Seams built now (no legal claim attached)

`tenant_id` and `account_id` in every schema; the in-process order-gateway contract; the `StrategyRuntime` port; the `license_tag` registry; the Taiwan gateway contract, which could become an edge connector ([ADR-0006](ADR-0006-broker-connectivity-and-gateway-contract.md)).

### Legal gate (trigger T1)

Before **any** second user, paid or free signal distribution, copy trading or external tenant, all of the following must exist:

1. **A written legal review** for every target jurisdiction (Taiwan FSC securities and futures advisory licensing and the VASP Act; US RIA/CTA/broker-dealer; EU MiCA where relevant), broker terms (third-party authorization, certificates, IBKR vendor rules), and market-data distribution agreements.
2. **Counsel's sign-off**, recorded as an ADR that supersedes or amends this one.
3. **Only then** the platform increment: out-of-process order gateway, tenancy, OIDC and WebAuthn, entitlements and licensed data distribution (Phase 4–5 budgets in the [main report](../../README.md)).

**Reverse trigger R1.** If no external users appear within about 12 months of building that increment, or the legal review is negative, collapse back to the lean design.

### Consequences

**Positive**

- No licensing exposure while the platform is used as intended.
- The point at which legal work must start is unambiguous and observable.
- The seams keep a service path open without paying the platform's operational cost early.

**Negative**

- Potentially useful activities (sharing signals with friends, a public dashboard) are blocked until legal review.
- A service, if wanted, still costs a legal project plus platform work: about 40–60 PM for the team platform (Phase 4) and about 60–70 PM more for an external offering (Phase 5). The seams reduce rework, not that cost.
- The posture depends on the owner's discipline. The software cannot detect every out-of-scope use.

### Confirmation

- Every limit, promotion and deployment record carries `tenant_id = 'self'`. Any other value fails a CI and runtime check until the T1 ADR exists.
- The API is reachable only over Tailscale for the owner's devices. Exposing any public endpoint or a second user account requires the T1 ADR.
- The yearly review re-verifies regulatory dates (VASP Act effective date, FINRA phase-in end, Taiwan tax expiries).

### Revisit when

- **T1** fires (a second user, a paid signal, copy trading or any external tenant).
- **T10:** a desktop or self-hosted product is planned, which brings licensing (LGPL) and possibly regulatory questions together.
- Law changes: the VASP Act's effective date and licensing, FINRA rule changes, or Taiwan broker API terms.

## Links

- [Main report: regulatory reminders, out-of-scope list, triggers T1 and R1, and the Taiwan-first vs US/crypto table](../../README.md)
- [Recommended architecture §9 (scenario-2 target)](../../architecture/recommended-architecture.md)
- [Evaluation record: grafts 21, 22, 23 and 25; concerns 4, 22, 23 and 24](../../architecture/evaluation.md)
- [Proposal C: regulatory posture and edge connector](../../architecture/proposal-C-platform-scale.md)
- Research: [08 Risk, security, operations and compliance](../../research/08-risk-security-ops-compliance.md) · [11 Taiwan localization](../../research/11-taiwan-market-localization.md) · [03 Data licensing](../../research/03-market-data-storage.md) · [04 Broker terms](../../research/04-broker-exchange-connectivity.md)
- Related ADRs: [ADR-0006](ADR-0006-broker-connectivity-and-gateway-contract.md) · [ADR-0008](ADR-0008-key-and-secret-management.md) · [ADR-0009](ADR-0009-open-source-licensing-strategy.md) · [ADR-0016](ADR-0016-multi-currency-books-tax-lots-and-tax-plugins.md) · [ADR-0017](ADR-0017-ai-trust-boundary.md)
