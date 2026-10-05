**English** | [繁體中文](ADR-0008-key-and-secret-management.zh-TW.md)

# ADR-0008: Key and secret management

## Status

**Proposed** · 2026-10-05 · Scope: scenario 1, with the scenario-2 move to OpenBao. This ADR resolves an inconsistency about where the Taiwan `.pfx` certificate is mounted (see *Context*).

## Context and problem statement

Credentials are the crown jewels of a trading system. A stolen trade key can lose money; a stolen withdrawal key can lose everything. The 2025 Bybit theft (about US$1.5B) came through the signing UI, and the npm "Shai-Hulud" worms (September and November 2025) stole credentials through dependencies ([08](../../research/08-risk-security-ops-compliance.md)). Where do secrets live, who can read them, and how are they rotated?

Secrets in scenario 1:

| Secret | Used by | Notes |
|---|---|---|
| Crypto venue API keys (HMAC, Ed25519, or ES256 for Coinbase) | `node-<account>`, `killswitch` | Can be scoped trade-only, withdrawal-disabled and IP-bound |
| IBKR username, password and IBC settings | `ib-gateway` | A human approves the periodic 2FA push. IBKR has no trade-only API keys |
| Taiwan CA certificate (`.pfx`) and its password, plus Shioaji API key and secret | `shioaji-sidecar`, `killswitch` | The certificate is **personal** (tied to the holder's ID) and cannot be pooled. Shioaji keys have scopes, expiry and an IP allow-list. Shioaji allows 5 concurrent sessions per person ID |
| Database roles, Telegram bot token, S3 export credentials, Tailscale auth key | `journal`, `api`, `scheduler`, host | — |
| Desktop API token (Phase 3 Tauri shell) | Client | Never a venue key |
| AI-scoped API tokens | AI tools (research assistants, coding agents, LLM signal generators) | Read data and create proposals only; no order, approval, control, limit or promotion rights; never stored on the trading host ([ADR-0017](ADR-0017-ai-trust-boundary.md)) |

**Inconsistency in the source documents (corrected on 2026-10-05).**

- The [main report](../../README.md) (security row), §2 of the [recommended architecture](../../architecture/recommended-architecture.md) ("the only container with the `.pfx` mounted") and the §8.4 go-live checklist all said the `.pfx` is mounted **only** into the Shioaji sidecar.
- Yet §3.5 and §3.12 gave the kill switch its own Shioaji session ("Shioaji client in the kill-switch container"; "mounted only into `shioaji-sidecar` (and the kill switch's Shioaji client)"). A Shioaji session that places or cancels orders needs the certificate.
- The README and §2 also said the kill switch has "its own credentials". For IBKR it actually shares the IB Gateway login (§3.5), and whether a second IBKR username gives an independent session is an open Phase 0 question.
- In the §7 split topology the kill switch ran in Tokyo, while the Taiwan broker's keys are bound to the home or Taipei IP.

Options for secret stores on 2026-10-05:

- OS keychains;
- SOPS + age (free);
- OpenBao 2.7.1 (MPL-2.0, Linux Foundation);
- HashiCorp Vault 2.1 (BSL 1.1, IBM; internal use is permitted);
- AWS Secrets Manager ($0.40 per secret per month);
- Infisical (MIT core with paid features).

## Decision drivers

- Least privilege: each container sees only the secrets it needs.
- Zero additional services for one operator.
- No venue key ever reaches a web, mobile or desktop client.
- An emergency path (the kill switch) that still works when a node is wedged.
- Auditable rotation and expiry tracking.
- A clean upgrade to a vault with an audit trail when a team or tenants arrive.

## Considered options

1. **SOPS + age encrypted files in git, decrypted only on the trading host and mounted per container as Docker secrets**, with a strict key policy.
2. **Self-hosted OpenBao (or Vault) from day one.**
3. **A cloud secret manager** (AWS Secrets Manager plus KMS).
4. **Plain `.env` files** on the host.
5. **OS keychain only** (desktop-centric).

## Decision outcome

**Chosen option: 1, "SOPS + age with per-container mounts"**, plus the key-hygiene rules below. It adds no service to operate, keeps an audited history in git, and gives per-container least privilege. OpenBao is the scenario-2 target.

### Storage and distribution

- Secrets are SOPS-encrypted YAML in `config/secrets/`. The age recipients are the trading host's key plus an offline recovery key. Neither private key exists on build machines or in CI.
- On deploy, secrets are decrypted on the trading host and mounted **read-only as Compose secrets** (files under `/run/secrets`) into the containers that need them. They are not passed as environment variables, which leak into `docker inspect` output, logs and crash dumps.
- PostgreSQL roles follow least privilege: the journal writer may only `INSERT` into `ledger_event`, and the API reads projections.

### Taiwan certificate (resolves the inconsistency)

- The `.pfx` and its password are mounted into **exactly two containers: `shioaji-sidecar` and `killswitch`**. They are never mounted into the node, the API, an image, git in plaintext or any client.
- The kill switch opens its own Shioaji session (one of the five allowed per person ID).
- **Amendment (applied on 2026-10-05):** the README security row, §2, §3.12 and the §8.4 checklist now say "only into the Shioaji sidecar and the kill-switch container", and the README and §2 state the IBKR caveat wherever the kill switch is described.
- In a split topology, the kill switch runs **one instance per site**. The Taiwan and IBKR paths run on the host whose static IP is on the broker's allow-list ([ADR-0013](ADR-0013-risk-gate-and-three-path-kill-switch.md)).

### Venue key policy

| Rule | Detail |
|---|---|
| Permissions | Trade and read only. Withdrawals are disabled everywhere. The system never holds a withdrawal-capable key |
| Binding | IP-bound to the host's static egress IP. Ed25519 where offered (for example Binance); ES256 for Coinbase |
| Granularity | One key per strategy or sub-account. The kill switch has **its own separate trade-only key** on each crypto (sub-)account |
| IBKR caveat | IBKR has no trade-only API keys. The kill switch uses its own TWS API client session through the shared IB Gateway login, so "own credentials" does not hold for IBKR until Phase 0 verifies a second username. The IBKR mobile app or web client is the manual last resort in the runbook |
| Rotation | Every 90 days and after any incident. The scheduler alerts 30 days before `.pfx` expiry, API-key expiry and rotation dates |
| Incident order | **Cancel resting orders before revoking keys.** Revoking a key does not cancel resting orders |
| Accounts | FIDO2 hardware keys on every broker, exchange, cloud, GitHub and package-registry account |
| Crypto custody | Only working capital stays on venues. The treasury stays in cold storage. Withdrawal-address allow-lists use a time lock |

### Clients and supply chain

- Web, PWA and Telegram clients hold no venue keys. They authenticate to the API over Tailscale with device-bound tokens; the Phase 3 Tauri shell stores its token in the OS keychain.
- Hash-pinned lockfiles (`uv.lock`, npm lockfile); a 3–7 day delay before adopting new versions; build machines separate from key-holding machines; SBOMs from Phase 2.
- Logs redact secrets, and secrets never appear in URLs or query strings.

### Scenario 2

- **OpenBao 2.7** (MPL-2.0) with a cloud-KMS root, audit devices, dynamic database credentials, automated rotation and per-tenant policies.
- In an external offering, personal Taiwan certificates stay on the customer-hosted edge connector, never on our servers.
- HashiCorp Vault (BSL 1.1) would be acceptable for internal use but is not chosen, because OpenBao gives the same API under a licence with no use restrictions. A cloud secret manager is an alternative for a fully cloud-hosted deployment.

### Consequences

**Positive**

- No secret-store service to run, back up or unseal in scenario 1.
- Every secret change is an encrypted, reviewable git commit.
- A compromise of the API, the UI or a node does not expose the Taiwan certificate.
- The kill switch keeps working when a node is wedged, because it holds its own crypto keys and its own Shioaji session.

**Negative**

- Secrets are static, rotation is manual (with scheduler reminders), and there is no per-read audit trail, unlike OpenBao.
- The trading host's age key is a high-value target. Host compromise exposes every secret, so the host must be dedicated and hardened.
- Two containers now hold the `.pfx` instead of one.
- For IBKR the kill switch is not independent of IB Gateway until a second username is verified.

### Confirmation

- The go-live checklist verifies key scopes (trade-only, withdrawal-disabled, IP-bound) on every venue, FIDO2 on every account, and that the `.pfx` appears only in the two named containers.
- A CI secret scanner runs on every merge. A Compose lint fails if secrets are passed through `environment:`.
- Rotation and expiry alerts fire in a test before Phase 2 exit.

### Revisit when

- **T1 or T2:** a team, tenants or several hosts → OpenBao on a cloud KMS.
- Phase 0 shows a second IBKR username gives a gateway-independent session → give the kill switch its own IBKR login.
- A desktop shell that trades directly from the desktop is ever considered → keys decrypted only in a trading-core process, never in the webview. Not planned.

## Links

- [Main report: security row, regulatory reminders and risks](../../README.md)
- [Recommended architecture §2, §3.5, §3.12, §7 and §8.4](../../architecture/recommended-architecture.md)
- [Evaluation record: concerns 3 and 7](../../architecture/evaluation.md)
- Research: [08 Risk, security, operations and compliance](../../research/08-risk-security-ops-compliance.md) · [04 Broker connectivity](../../research/04-broker-exchange-connectivity.md) · [11 Taiwan localization](../../research/11-taiwan-market-localization.md)
- Related ADRs: [ADR-0005](ADR-0005-messaging-and-deployment-topology.md) · [ADR-0006](ADR-0006-broker-connectivity-and-gateway-contract.md) · [ADR-0013](ADR-0013-risk-gate-and-three-path-kill-switch.md) · [ADR-0015](ADR-0015-self-use-regulatory-posture-and-legal-gate.md)
