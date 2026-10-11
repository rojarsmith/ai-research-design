[English](README.md) | **繁體中文**

# AI 研究與設計

整理軟體平台的工程研究、可行性分析與架構提案。每個主題各有獨立目錄、主報告、延伸研究與參考資料；可先從想了解的主題主報告開始閱讀。

## 研究主題

| 主題 | 範圍 | 英文 | 繁體中文 |
| --- | --- | --- | --- |
| 多資產交易平台 | 股票、加密貨幣、債券與選擇權的市場資料、分析、回測、券商連線、風控及部署，涵蓋台灣市場 | [Main report](multi-asset-trading-platform/README.md) | [主報告](multi-asset-trading-platform/README.zh-TW.md) |
| VPS 上的 OpenRouter 用量平台 | 快速部署方案、上游授權、API Key、預付額度、帳務、成本試算與驗收 | [Main report](openrouter-vps-token-platform/README.md) | [主報告](openrouter-vps-token-platform/README.zh-TW.md) |
| SSL.com OV Code Signing 驗證 | 台灣公司登記、第三方地址及電話資料、上傳 PDF 與回撥準備 | [Main report](code-signing-research/README.md) | [主報告](code-signing-research/README.zh-TW.md) |

## 主要文件

| 文件 | 用途 |
| --- | --- |
| [交易平台建議架構](multi-asset-trading-platform/architecture/recommended-architecture.zh-TW.md) | 建議架構與實作方向 |
| [交易平台架構評估](multi-asset-trading-platform/architecture/evaluation.zh-TW.md) | 各架構提案的比較 |
| [交易平台決策紀錄](multi-asset-trading-platform/docs/adr/README.zh-TW.md) | 設計決策的理由與取捨 |
| [OpenRouter 可行性與方案](openrouter-vps-token-platform/research/01-feasibility-and-options.zh-TW.md) | 商業模式、工具比較、授權與成本試算 |
| [OpenRouter VPS 建置路線](openrouter-vps-token-platform/research/02-vps-mvp-roadmap.zh-TW.md) | 最小產品範圍、部署順序與驗收案例 |
| [OpenRouter 來源與待確認事項](openrouter-vps-token-platform/research/03-sources-and-open-questions.zh-TW.md) | 官方資料與上線前須確認的問題 |

## 目錄導覽

| 目錄 | 內容 |
| --- | --- |
| `multi-asset-trading-platform/research/` | 各子系統與市場需求的研究 |
| `multi-asset-trading-platform/architecture/` | 架構提案、評估與建議設計 |
| `multi-asset-trading-platform/docs/adr/` | 架構決策紀錄 |
| `openrouter-vps-token-platform/research/` | 可行性、部署、帳務與來源資料 |

## 閱讀與語言慣例

1. 先閱讀主題主報告，了解範圍、假設、結論與文件入口。
2. 再依延伸研究與決策紀錄查看證據及實作細節。
3. 解讀版本、價格與條款時，以報告標示的研究日期為準；實作前重新查核可能變動的資訊。

文件以英文為預設語言，對應的 `*.zh-TW.md` 提供繁體中文版，每份文件頂部都有語言切換連結。各語言版本的導覽連至同語言文件。

研究以證據與使用者需求為中心，對廠商採用相同查證標準，並區分已記載的功能、估算與建議設計。閱讀建議、工期及成本估算時，應一併考量其假設與限制。
