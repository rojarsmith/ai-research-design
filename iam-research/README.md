**English overview** | [完整繁體中文指南](README.zh-TW.md)

# IAM comparison and Keycloak operations research

Research date: 2026-10-12, Asia/Taipei.

This directory compares eleven IAM product families and provides integration patterns, deployment guidance, and an operations runbook for an existing Keycloak installation. The user reports using the latest version but does not remember the original deployment method. The installed version, host, database, proxy, and recovery arrangements need to be inventoried before making changes.

The complete research is in Traditional Chinese. Start with the [main guide](README.zh-TW.md), then the [existing deployment inventory](templates/current-deployment.zh-TW.md). The requested [iThome series](https://ithelp.ithome.com.tw/users/20112470/ironman/4324) is incorporated through a complete 41-entry index, reading paths, and verified corrections to selected articles. This directory contains summaries and original operational guidance, not a full reproduction of the articles.

| Document | Purpose |
| --- | --- |
| [IAM comparison](research/01-iam-comparison.zh-TW.md) | Keycloak, authentik, ZITADEL, Ory, Auth0, Okta, Microsoft Entra, Cognito, Firebase/Identity Platform, PingFederate, WSO2 |
| [Integration patterns](research/02-integration.zh-TW.md) | Web, APIs, native apps, M2M, enterprise federation, provisioning, authorization |
| [iThome reference](research/03-ithome-series.zh-TW.md) | All 41 links, source scope, topic summaries, migration corrections |
| [Deployment guide](research/04-keycloak-deployment.zh-TW.md) | Inventory first, lab environment, production design, phased changes |
| [Operations runbook](research/05-keycloak-operations.zh-TW.md) | Monitoring, recovery, upgrades, account lifecycle, incident handling |
| [Acceptance checklist](research/06-acceptance.zh-TW.md) | Positive and negative security and recovery scenarios |
| [Sources](research/07-sources.zh-TW.md) | Primary documentation and evidence boundaries |
| [Local lab](examples/keycloak-lab/README.zh-TW.md) | Isolated Compose example; no connection to the existing installation |

The current official Keycloak download and documentation pages show 26.8.0. That is a research reference, not evidence of the version installed by the user. No live Keycloak installation was accessed or changed, and the container example has not been runtime-tested in this workspace.
