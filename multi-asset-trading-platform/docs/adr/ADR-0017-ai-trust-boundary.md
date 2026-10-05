**English** | [繁體中文](ADR-0017-ai-trust-boundary.zh-TW.md)

# ADR-0017: AI trust boundary: proposals only, scoped tokens, isolation and audit

## Status

**Proposed** · 2026-10-05 · Scope: scenarios 1 and 2. It applies from the first AI tool that touches the platform, not only when trigger T11 (automated strategy mining) fires.

## Context and problem statement

AI tools will be used for coding, research and possibly signal generation. Research [09](../../research/09-research-ml-analytics.md) lists guardrails it calls non-negotiable, but the adopted design carried over only part of them ([ADR-0014](ADR-0014-two-tier-backtesting-and-promotion-gates.md): read-only MCP tools, sandboxed AI-written code, broker MCP servers on paper only). Missing were the rules that keep an AI tool from moving money or leaking secrets.

Forces:

- **Agents act beyond scope.** The 2026 FINRA report warns that agents may act "beyond the user's actual or intended scope", and OWASP LLM01:2025 calls for least privilege and a human in the loop for privileged operations.
- **Prompt injection.** News, filings and web pages that an assistant reads can carry instructions. Tool-poisoned or malicious MCP servers are a related risk.
- **Secrets.** A coding agent on the trading host could read `/run/secrets`, the age key or the Telegram bot token. Some broker MCP servers can place live orders (the Alpaca MCP server defaults to paper but has a trading toolset).
- **Licences.** Sending licensed market data to a third-party LLM API can breach the data licence.
- **A landing place now exists.** Semi-automated trading adds proposals with human approval ([recommended architecture](../../architecture/recommended-architecture.md) §3.13), so AI output has a safe, audited destination.

## Decision drivers

- No AI tool can place, approve or modify an order, or change a limit, directly or indirectly.
- No AI tool can read secrets or reach venues.
- Every AI action that could affect trading is attributable and auditable.
- Licensed data never leaves for a third-party model without permission.
- Cheap to enforce for one person (about 0.15 PM in Phase 2a if AI tools are in use).

## Considered options

1. **A hard trust boundary:** AI output becomes proposals only, with scoped tokens, network isolation, no secrets, an audit log and a licence check.
2. **Read-only AI only:** no proposals at all.
3. **Autonomous AI trading within small risk limits.**
4. **No AI tools.**

## Decision outcome

**Chosen option: 1.** It keeps the useful part of AI (research, code, trade ideas) and puts a human and the same risk gate between the model and the market. Option 2 wastes the approval queue that exists anyway; option 3 contradicts research 09 and the FINRA and OWASP guidance; option 4 is unnecessary.

### Rules and enforcement

| Rule | Enforcement |
|---|---|
| **Proposals only.** LLM output that suggests a trade becomes a `TradeProposal` with `proposer = AI` and the trace ID; it goes through `tp_risk` and the human approval queue. There is no auto-approval for AI proposals | The API accepts AI proposals only from AI-scoped tokens and marks them; the approval endpoint refuses approvals from AI-scoped tokens; a CI test covers both |
| **Scoped tokens.** AI tools get tokens with read scopes (market data, research results, positions if the owner allows) and `proposals:create` only | Scope checks in the API. A CI test asserts HTTP 403 for an AI-scoped token on `POST /v1/orders`, proposal approval, `/v1/control/*`, `PUT /v1/limits/*` and `/v1/promotions/*` |
| **No control channel.** AI tools cannot use Telegram or ntfy control commands | The bot token is never mounted into an AI container; the bot accepts commands only from the owner's chat ID, with the PIN |
| **No secrets.** No `/run/secrets`, SOPS files, age keys or venue keys in any AI container | Compose lint fails if an AI service mounts secrets; the secret scanner runs on every merge |
| **No coding agents on the key-holding host.** | Coding agents run on the workstation or a separate build VM ([ADR-0008](ADR-0008-key-and-secret-management.md): build machines are separate from key-holding machines) |
| **Network isolation.** AI services live on a separate Docker network (and host, for coding agents) that reaches only the read-only MCP server, the proposals endpoint and an allow-list of LLM APIs | Compose network definitions plus host firewall rules; no route to venues, IB Gateway, the Shioaji sidecar, the Valkey control streams or PostgreSQL write roles; a network test in CI |
| **Untrusted input.** News, filings and web text are treated as prompt-injection vectors | Retrieval tools are separate from action tools; retrieved text is labelled untrusted in prompts; the only action any AI tool has is creating a proposal, which a human reviews |
| **Audit.** Every prompt, tool call, output and resulting proposal is logged | MLflow tracing plus an append-only log; proposals carry the trace ID; ledger events record proposal creation and its outcome |
| **Licensed data.** Each `license_tag` in the licence registry has an `llm_export_allowed` flag (default false) | The in-house MCP server checks the flag before returning data destined for a third-party LLM API; locally hosted models are recorded separately |
| **Broker MCP servers on paper only.** | Live credentials are never loaded into an LLM client; data-only toolsets where offered |
| **MCP supply chain.** | MCP servers only from pinned, reviewed sources, run sandboxed; no token passthrough |

### Consequences

**Positive**

- An AI tool, even a compromised or manipulated one, cannot move money, change limits or read keys; the worst case is a bad proposal that a human rejects.
- Every AI contribution to a trade is traceable from the ledger to the prompt.
- Licence obligations hold when data is used with hosted models.

**Negative**

- Human approval makes AI-generated trades slow; latency-sensitive AI signals are out of scope.
- Scopes, networks and the audit log are extra configuration to maintain, and the `llm_export_allowed` flag needs each licence read.
- The owner can still approve a bad proposal; the boundary protects against the tool, not against judgement.

### Confirmation

- CI: the 403 tests for AI-scoped tokens, the Compose secret-mount lint, the network reachability test, and the approval-refusal test.
- Phase 2a exit (if AI tools are in use): a red-team exercise in which a planted instruction in a news item tries to make an assistant place an order; it must end as a proposal at most.
- Quarterly: review the audit log sample and the MCP server pins.

### Revisit when

- **T11:** automated factor mining or AI-generated strategies → platform-wide trial counting and sandboxed execution as well ([ADR-0014](ADR-0014-two-tier-backtesting-and-promotion-gates.md)).
- **T1 or T2:** a central MCP gateway with per-user scopes, four-eyes approval of AI proposals (proposer is never the approver), and per-tenant data entitlements.
- Broker or exchange APIs gain agent-specific permission models.

## Links

- [Main report: security row, trigger T11 and the AI decision](../../README.md)
- [Recommended architecture §3.8, §3.10, §3.13 and §3.14](../../architecture/recommended-architecture.md)
- Research: [09 Research, ML and analytics (guardrails)](../../research/09-research-ml-analytics.md) · [08 Security](../../research/08-risk-security-ops-compliance.md)
- Related ADRs: [ADR-0008](ADR-0008-key-and-secret-management.md) · [ADR-0009](ADR-0009-open-source-licensing-strategy.md) · [ADR-0013](ADR-0013-risk-gate-and-three-path-kill-switch.md) · [ADR-0014](ADR-0014-two-tier-backtesting-and-promotion-gates.md)
