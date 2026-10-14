**English** | [繁體中文](README.zh-TW.md)

# AI Research and Design

Engineering research, feasibility studies, architecture proposals for software platforms, and cross-border business research. Each topic has its own directory, main report, supporting research, and references. Start with the main report for the topic you want to explore.

## Research Topics

| Topic | Scope | English | Traditional Chinese |
| --- | --- | --- | --- |
| Save and load compatibility | Large application and game save architecture, schema evolution, content migration, safe commits and verification | [English overview](save-load-compatibility-research/README.md) | [完整研究](save-load-compatibility-research/README.zh-TW.md) |
| MCU embedded HMI ecosystem | Eight offerings across UI tools, graphics frameworks, display controllers, MCU platforms and smart displays; licensing, architecture and evaluation | [English overview](mcu-embedded-hmi-research/README.md) | [完整研究](mcu-embedded-hmi-research/README.zh-TW.md) |
| IAM comparison and Keycloak operations | Eleven IAM product families, application integration, the requested iThome series, deployment inventory, recovery and operations | [English overview](iam-research/README.md) | [完整研究](iam-research/README.zh-TW.md) |
| Software platform payment integration | Platform integration directions, provider comparison framework, and verified Stripe test cards and acceptance scenarios | [English overview](payment-integration-research/README.md) | [完整研究](payment-integration-research/README.zh-TW.md) |
| Website maintenance and VPS failover | Maintenance messages, nginx failure boundaries, primary A and standby B routing, automatic failback, costs and validation | [English overview](website-availability-research/README.md) | [完整研究](website-availability-research/README.zh-TW.md) |
| Multi-asset trading platform | Market data, analysis, backtesting, broker connectivity, risk controls, and deployment across stocks, crypto, bonds, and options, including Taiwan markets | [Main report](multi-asset-trading-platform/README.md) | [主報告](multi-asset-trading-platform/README.zh-TW.md) |
| OpenRouter usage platform on a VPS | Rapid deployment options, upstream authorization, API keys, prepaid credits, billing, cost examples, and acceptance checks | [Main report](openrouter-vps-token-platform/README.md) | [主報告](openrouter-vps-token-platform/README.zh-TW.md) |
| SSL.com OV Code Signing validation | Taiwan company registration, third-party address and telephone records, upload PDFs, and callback preparation | [Main report](code-signing-research/README.md) | [主報告](code-signing-research/README.zh-TW.md) |
| Operating a U.S. company from Taiwan | Structures, states, preparation, U.S. and Taiwan taxes, setup and annual budgets, maintenance calendar, and owner operations; public research only | [English overview](us-company-from-taiwan/README.md) | [完整攻略](us-company-from-taiwan/README.zh-TW.md) |
| Blender development history | Origins, open-source transition, architecture, production feedback, funding, and commercial readiness | [English overview](blender-development-research/README.md) | [完整研究](blender-development-research/README.zh-TW.md) |
| PC troubleshooting and solutions | Windows event analysis, symptom-based diagnostics, evidence collection, and an offline bilingual guide | [Main report](pc-troubleshooting/README.md) | [完整攻略](pc-troubleshooting/README.zh-TW.md) |
| Desktop display wake research | RTX 5070 Ti, Acer ET322QK, ASUS VG289, Philips HDMI switching, Windows sleep, driver recovery and 20 official references | [English report](display-wake-research/README.md) | [繁體中文研究](display-wake-research/README.zh-TW.md) |
| Claude Startups applications | Current eligibility and benefits, HMI Studio applicant assessment, Max API credits and English inquiry drafts | [English overview](claude-startups-research/README.md) | [完整研究](claude-startups-research/README.zh-TW.md) |
| Online dating and family planning | Kaohsiung and international dating channels, platform limits, profiles, a 30-day plan, sources and research log | [English overview](marriage-and-dating/README.md) | [完整研究](marriage-and-dating/README.zh-TW.md) |
| Motorcycle accident evidence and claims | Evidence preservation, police records, medical documentation, motorcycle repair and insurance for a two-motorcycle avoidance-crash case | [Case guide](motorcycle-accident-research/README.zh-TW.md) | [繁體中文行動指南](motorcycle-accident-research/README.zh-TW.md) |

## Key Documents

New topic: [LOXJIE A40 USB audio fault research](loxjie-a40-usb-research/README.md), covering local drivers and USB topology, online reports, controlled comparisons, and a read-only evidence collector.

| Document | Purpose |
| --- | --- |
| [Trading platform recommended architecture](multi-asset-trading-platform/architecture/recommended-architecture.md) | Proposed architecture and implementation direction |
| [Trading platform architecture evaluation](multi-asset-trading-platform/architecture/evaluation.md) | Comparison of the architecture proposals |
| [Trading platform decision records](multi-asset-trading-platform/docs/adr/README.md) | Rationale and tradeoffs behind design decisions |
| [OpenRouter feasibility and options](openrouter-vps-token-platform/research/01-feasibility-and-options.md) | Business models, tool comparison, licensing, and cost example |
| [OpenRouter VPS deployment roadmap](openrouter-vps-token-platform/research/02-vps-mvp-roadmap.md) | Minimum product scope, deployment sequence, and acceptance cases |
| [OpenRouter sources and open questions](openrouter-vps-token-platform/research/03-sources-and-open-questions.md) | Official references and questions to resolve before launch |

## Directory Guide

| Directory | Contents |
| --- | --- |
| `save-load-compatibility-research/` | Save/load architecture, public implementations, migration examples, compatibility scenarios and primary sources |
| `iam-research/` | IAM comparison, Keycloak integration and operations, source index, deployment inventory, and an isolated local lab |
| `mcu-embedded-hmi-research/` | MCU HMI ecosystem comparison, product capabilities, architecture, evaluation protocol and official sources |
| `payment-integration-research/research/` | Stripe test cards, source corrections, and payment integration acceptance scenarios |
| `website-availability-research/` | Website maintenance and A/B failover research, cost models, implementation guide, official sources and nginx templates |
| `multi-asset-trading-platform/research/` | Research by subsystem and market requirements |
| `multi-asset-trading-platform/architecture/` | Architecture proposals, evaluation, and recommended design |
| `multi-asset-trading-platform/docs/adr/` | Architecture decision records |
| `openrouter-vps-token-platform/research/` | Feasibility, deployment, billing, and source material |
| `us-company-from-taiwan/research/` | General research on operating U.S. companies from Taiwan; private case records remain outside Git |
| `blender-development-research/research/` | Blender engineering, production workflows, references, and evidence boundaries |
| `pc-troubleshooting/` | PC failure research, screenshot event catalog, diagnostic workflow, case templates and local tools |
| `display-wake-research/` | RTX 5070 Ti desktop HDMI/DP dual-monitor wake issue and supporting sources |
| `motorcycle-accident-research/` | Motorcycle accident case guide, source checks, official procedures and evidence checklist |

## Reading and Language Conventions

1. Read a topic's main report for scope, assumptions, conclusions, and document links.
2. Follow the supporting research and decision records for evidence and implementation details.
3. Use the report's stated research date when interpreting versions, prices, and terms. Recheck time-sensitive inputs before implementation.

Most topics provide English documents and matching `*.zh-TW.md` Traditional Chinese versions, with navigation within each language leading to that language's documents. The U.S. company operating guide and Blender research are complete in Traditional Chinese; their English entries are explicitly overviews.

Research follows evidence and the user's requirements, applies the same verification standards to vendors, and distinguishes documented capabilities from estimates and proposed designs. Recommendations and effort or cost estimates should be read together with their assumptions and limitations.
