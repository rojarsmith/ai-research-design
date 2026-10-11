**English** | [繁體中文](README.zh-TW.md)

# AI Research and Design

Engineering research, feasibility studies, architecture proposals for software platforms, and cross-border business research. Each topic has its own directory, main report, supporting research, and references. Start with the main report for the topic you want to explore.

## Research Topics

| Topic | Scope | English | Traditional Chinese |
| --- | --- | --- | --- |
| Multi-asset trading platform | Market data, analysis, backtesting, broker connectivity, risk controls, and deployment across stocks, crypto, bonds, and options, including Taiwan markets | [Main report](multi-asset-trading-platform/README.md) | [主報告](multi-asset-trading-platform/README.zh-TW.md) |
| OpenRouter usage platform on a VPS | Rapid deployment options, upstream authorization, API keys, prepaid credits, billing, cost examples, and acceptance checks | [Main report](openrouter-vps-token-platform/README.md) | [主報告](openrouter-vps-token-platform/README.zh-TW.md) |
| SSL.com OV Code Signing validation | Taiwan company registration, third-party address and telephone records, upload PDFs, and callback preparation | [Main report](code-signing-research/README.md) | [主報告](code-signing-research/README.zh-TW.md) |
| Operating a U.S. company from Taiwan | Structures, states, preparation, U.S. and Taiwan taxes, setup and annual budgets, maintenance calendar, and owner operations; public research only | [English overview](us-company-from-taiwan/README.md) | [完整攻略](us-company-from-taiwan/README.zh-TW.md) |

## Key Documents

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
| `multi-asset-trading-platform/research/` | Research by subsystem and market requirements |
| `multi-asset-trading-platform/architecture/` | Architecture proposals, evaluation, and recommended design |
| `multi-asset-trading-platform/docs/adr/` | Architecture decision records |
| `openrouter-vps-token-platform/research/` | Feasibility, deployment, billing, and source material |
| `us-company-from-taiwan/research/` | General research on operating U.S. companies from Taiwan; private case records remain outside Git |

## Reading and Language Conventions

1. Read a topic's main report for scope, assumptions, conclusions, and document links.
2. Follow the supporting research and decision records for evidence and implementation details.
3. Use the report's stated research date when interpreting versions, prices, and terms. Recheck time-sensitive inputs before implementation.

Most topics provide English documents and matching `*.zh-TW.md` Traditional Chinese versions, with navigation within each language leading to that language's documents. The U.S. company operating guide is complete in Traditional Chinese; its English entry is explicitly an overview.

Research follows evidence and the user's requirements, applies the same verification standards to vendors, and distinguishes documented capabilities from estimates and proposed designs. Recommendations and effort or cost estimates should be read together with their assumptions and limitations.
