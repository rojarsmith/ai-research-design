[English](03-sources-and-open-questions.md) | **繁體中文**

# 官方來源與上線前待確認事項

查閱日期：2026-10-09。來源包含現行官方文件與主分支原始碼；`main` 會改變，實際部署時須固定版本並保存相應 LICENSE、NOTICE、配置與映像 digest。

## 來源對照

| 來源 | 本研究採用的資訊 |
| --- | --- |
| [OpenRouter 條款](https://openrouter.ai/terms) | 更新日期 2026-08-31；轉售限制、credits 不可轉讓、應用與模型條款 |
| [OpenRouter Pricing](https://openrouter.ai/pricing) | Standard 5.5%、Business 8%；方案不同，不推定提供轉售權 |
| [OpenRouter FAQ](https://openrouter.ai/docs/faq) | 模型計費維度與充值模式 |
| [OpenRouter OAuth](https://openrouter.ai/docs/guides/overview/auth/oauth) | 用戶授權並取得用戶控制的 API Key |
| [OpenRouter Management API](https://openrouter.ai/docs/guides/overview/auth/management-api-keys) | Key 管理、限額與管理憑證權限 |
| [OpenRouter 用量核算](https://openrouter.ai/docs/cookbook/administration/usage-accounting) | usage、cost、串流末尾資料與 generation ID 查詢 |
| [New API 快速開始](https://docs.newapi.pro/en/docs) | 部署、channel 設定、平台 token 的起步流程 |
| [New API README](https://github.com/QuantumNous/new-api/blob/main/README.md) | Docker、儲存與 HTTPS Cookie 配置 |
| [New API Compose](https://github.com/QuantumNous/new-api/blob/main/docker-compose.yml) | PostgreSQL、Redis、示範秘密與網路配置 |
| [New API Channel 文件](https://docs.newapi.pro/zh/docs/guide/feature-guide/admin/channel) | 模型及上游設定 |
| [New API Channel 原始碼](https://github.com/QuantumNous/new-api/blob/main/constant/channel.go) | OpenRouter channel 類型與基底網址 |
| [New API 錢包](https://docs.newapi.pro/zh/docs/guide/feature-guide/user/wallet) | 儲值、兌換碼、訂閱與支付啟用條件 |
| [New API LICENSE](https://github.com/QuantumNous/new-api/blob/main/LICENSE) 與 [NOTICE](https://github.com/QuantumNous/new-api/blob/main/NOTICE) | AGPLv3 與指定署名、可見專案連結 |
| [LiteLLM Docker 起步](https://docs.litellm.ai/docs/proxy/docker_quick_start) | 容器與虛擬 Key 起步 |
| [LiteLLM OpenRouter](https://docs.litellm.ai/docs/providers/openrouter) | OpenRouter 轉接 |
| [LiteLLM 虛擬 Key](https://docs.litellm.ai/docs/proxy/virtual_keys) | Key 與預算功能 |
| [LiteLLM LICENSE](https://github.com/BerriAI/litellm/blob/main/LICENSE) | MIT 範圍與 enterprise 例外 |
| [Stripe Webhook](https://docs.stripe.com/webhooks) | 簽章、重複事件與事件順序限制 |

這些官方資料適合查核產品介面與規範，不代表獨立效能或安全評測。方案排序來自需自行補足工作的比較；工期、硬體、付款費率與毛利情境均為本研究規劃假設。

## 授權資料的版本差異

New API 的[封存舊文件](https://github.com/QuantumNous/new-api-docs/blob/main/docs/wiki/project-introduction.md)曾描述較廣泛的品牌保留要求；現行 LICENSE 和 NOTICE 的內容不同。採用時應以選定版本的授權文件確認義務，不能從舊說明直接推定目前所有換 Logo 行為都要購買商業授權，也不能忽略現行 NOTICE 的指定署名要求。

OpenRouter 的標準條款禁止轉售，而 Management API 又描述 SaaS 的每客戶 Key 管理。兩者可同時成立：文件提供某種管理功能，不等於准許所有使用該功能的商業模式。需要取得針對具體產品的書面答覆與適用協議。

## 必須確認的商業資訊

| 問題 | 對方案的影響 |
| --- | --- |
| 客戶購買的是通用 API 存取還是特定應用功能 | 決定上游轉售授權與產品設計 |
| 營運主體、客戶所在地與目標模型 | 決定支付商資格與模型服務範圍 |
| 平均每客戶用量、付款金額、付款頻率 | 決定加價、固定服務費與最低儲值額 |
| 是否需要閉源修改或移除指定署名 | 決定 New API 或 LiteLLM 的授權策略 |
| 首批客戶需要哪些客戶端與端點 | 決定相容性驗收，影響工期 |
| 是否有上游書面轉售授權與責任分工 | 決定是否可公開販售及如何訂客戶條款 |

## 給 OpenRouter 的詢問草稿

以下是可自行提交的草稿，尚未寄送。

> We are evaluating a VPS-hosted platform where customers register, purchase service credits, receive our platform API keys, and call selected models through an OpenAI-compatible endpoint. Our backend would use an OpenRouter organization account, meter usage, and charge customers our published rates.
>
> We understand that Section 7.4 of the current Terms prohibits resale of API access. Do you offer a separate agreement that explicitly permits this model? If so, please clarify covered models, customer territories, downstream terms, usage and abuse responsibilities, data processing obligations, key-management requirements, pricing, and termination arrangements.
>
> Please also distinguish this arrangement from embedding OpenRouter in a value-added application, and from an application where each customer connects their own OpenRouter account through OAuth and pays you directly for model usage. We would like to confirm the permitted scope before enabling public sales.

後續部署決策應記錄所用版本、授權文件、核價模型、支付條件與驗收結果。若轉售協議不可得，保留「改用適當授權的上游」與「客戶自帶 Key 的自有應用」兩條路線，再依商品需求選擇。
