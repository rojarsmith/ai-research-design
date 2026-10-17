[English](README.md) | **繁體中文**

# AI 研究與設計

整理軟體平台的工程研究、可行性分析、架構提案與跨境經營研究。每個主題各有獨立目錄、主報告、延伸研究與參考資料；可先從想了解的主題主報告開始閱讀。

## 研究主題

| 主題 | 範圍 | 英文 | 繁體中文 |
| --- | --- | --- | --- |
| 存讀檔與版本相容性 | 大型軟體與遊戲的存檔架構、資料與內容遷移、安全提交及驗證 | [English overview](save-load-compatibility-research/README.md) | [完整研究](save-load-compatibility-research/README.zh-TW.md) |
| MCU 嵌入式 HMI 生態 | 八項 UI 工具、圖形框架、控制晶片、MCU 與智慧顯示方案；授權、架構與評測方法 | [English overview](mcu-embedded-hmi-research/README.md) | [完整研究](mcu-embedded-hmi-research/README.zh-TW.md) |
| IAM 比較與 Keycloak 營運 | 11 組 IAM 方案、應用整合、指定 iThome 系列、部署盤點、備份還原與營運 | [English overview](iam-research/README.md) | [完整研究](iam-research/README.zh-TW.md) |
| 軟體平台支付整合 | 平台串接方向、支付服務比較框架，以及官方核對的 Stripe 測試卡與驗收情境 | [English overview](payment-integration-research/README.md) | [完整研究](payment-integration-research/README.zh-TW.md) |
| 網站維護與 VPS 故障切換 | 維護訊息、nginx 故障邊界、A 主機與 B 備援、自動切回、成本及驗收 | [English overview](website-availability-research/README.md) | [完整研究](website-availability-research/README.zh-TW.md) |
| 多資產交易平台 | 股票、加密貨幣、債券與選擇權的市場資料、分析、回測、券商連線、風控及部署，涵蓋台灣市場 | [Main report](multi-asset-trading-platform/README.md) | [主報告](multi-asset-trading-platform/README.zh-TW.md) |
| VPS 上的 OpenRouter 用量平台 | 快速部署方案、上游授權、API Key、預付額度、帳務、成本試算與驗收 | [Main report](openrouter-vps-token-platform/README.md) | [主報告](openrouter-vps-token-platform/README.zh-TW.md) |
| SSL.com OV Code Signing 驗證 | 台灣公司登記、第三方地址及電話資料、上傳 PDF 與回撥準備 | [Main report](code-signing-research/README.md) | [主報告](code-signing-research/README.zh-TW.md) |
| 台灣居民經營美國公司 | 組織與州別方案、準備、台美稅務、初期及年度成本、維護行事曆與老闆手冊；僅公開研究 | [English overview](us-company-from-taiwan/README.md) | [完整攻略](us-company-from-taiwan/README.zh-TW.md) |
| Blender 研發歷程 | 起步、開源轉型、架構、製作回饋、經費與商業成熟度 | [English overview](blender-development-research/README.md) | [完整研究](blender-development-research/README.zh-TW.md) |
| PC 故障分析與解法 | Windows 事件判讀、依症狀排查、證據蒐集及離線雙語查閱頁 | [Main report](pc-troubleshooting/README.md) | [完整攻略](pc-troubleshooting/README.zh-TW.md) |
| 桌機螢幕喚醒研究 | RTX 5070 Ti、Acer ET322QK、ASUS VG289 與 Philips HDMI 切換；Windows 睡眠、驅動、型號設定及 20 項官方來源 | [English report](display-wake-research/README.md) | [繁體中文研究](display-wake-research/README.zh-TW.md) |
| 電腦圖形學實作課程 | 從向量與軟體光柵化開始，逐步打造小型即時渲染器；提供可離線使用的雙語互動課程 | [English course](computer-graphics-practice/README.md) | [繁體中文課程](computer-graphics-practice/README.zh-TW.md) |
| Claude Startups 申請 | 最新資格與福利、HMI Studio 申請主體評估、Max API 額度與英文詢問草稿 | [English overview](claude-startups-research/README.md) | [完整研究](claude-startups-research/README.zh-TW.md) |
| 網路交友與婚育規劃 | 高雄與跨國認識管道、平台限制、自介與30天行動、來源與研究紀錄 | [English overview](marriage-and-dating/README.md) | [完整研究](marriage-and-dating/README.zh-TW.md) |
| 機車事故證據與求償 | 對向機車左轉、閃避摔車個案的證據保全、警方資料、醫療、機車修復與求償程序 | [研究目錄](motorcycle-accident-research/README.zh-TW.md) | [個案行動指南](motorcycle-accident-research/README.zh-TW.md) |

## 主要文件

新增主題：[LOXJIE A40 USB 爆音與斷聲研究](loxjie-a40-usb-research/README.zh-TW.md)，包含本機驅動與 USB 拓撲、網路案例、對照測試及唯讀採集工具。

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
| `save-load-compatibility-research/` | 存讀檔架構、公開實作、遷移範例、相容性情境與官方來源 |
| `iam-research/` | IAM 比較、Keycloak 整合與營運、來源索引、現況盤點及獨立本地實驗環境 |
| `mcu-embedded-hmi-research/` | MCU HMI 生態、產品能力、系統架構、評測方法與官方來源 |
| `payment-integration-research/research/` | Stripe 測試卡、來源修正與支付整合驗收情境 |
| `website-availability-research/` | 網站維護與 A/B 故障切換、成本模型、實作指南、官方來源及 nginx 模板 |
| `multi-asset-trading-platform/research/` | 各子系統與市場需求的研究 |
| `multi-asset-trading-platform/architecture/` | 架構提案、評估與建議設計 |
| `multi-asset-trading-platform/docs/adr/` | 架構決策紀錄 |
| `openrouter-vps-token-platform/research/` | 可行性、部署、帳務與來源資料 |
| `us-company-from-taiwan/research/` | 台灣居民經營美國公司的通用研究；私人個案資料保存在 Git 之外 |
| `blender-development-research/research/` | Blender 工程、製作流程、參考來源與證據範圍 |
| `pc-troubleshooting/` | PC 故障研究、截圖事件表、排查流程、個案範本與本機工具 |
| `display-wake-research/` | RTX 5070 Ti 桌機 HDMI/DP 雙螢幕喚醒問題與證據來源 |
| `computer-graphics-practice/` | 雙語電腦圖形學實作課程與可執行瀏覽器實驗 |
| `motorcycle-accident-research/` | 機車事故個案行動指南、六篇參考文章摘要與查核、官方程序與證據清單 |

## 閱讀與語言慣例

1. 先閱讀主題主報告，了解範圍、假設、結論與文件入口。
2. 再依延伸研究與決策紀錄查看證據及實作細節。
3. 解讀版本、價格與條款時，以報告標示的研究日期為準；實作前重新查核可能變動的資訊。

文件通常提供英文與對應的 `*.zh-TW.md` 繁體中文版，各語言導覽連至同語言文件。美國公司經營攻略與 Blender 研究以繁體中文為完整版本，英文入口明示為概要。

研究以證據與使用者需求為中心，對廠商採用相同查證標準，並區分已記載的功能、估算與建議設計。閱讀建議、工期及成本估算時，應一併考量其假設與限制。
