[English](01-feasibility-and-options.md) | **繁體中文**

# OpenRouter 用量平台的可行性與快速方案

研究日期：2026-10-09。預設需求為 API 用量平台：客戶註冊、取得 Key、購買平台額度，再使用 OpenAI 相容介面。VPS 負責驗證、代理與帳務，模型推論由上游處理，因此這條路線不需要在 VPS 配置 GPU。

最少開發的選擇是 New API；需要自行設計產品與帳務時，選 LiteLLM。真正影響能否公開販售的是上游授權與扣款正確性，安裝容器只是其中一部分。

## 商品與授權範圍

「Token」須區分三種概念：API Key 是存取憑證，模型 token 是用量單位，平台額度是客戶購買的服務額度。不同模型的輸入、輸出、快取及其他費用不同，不能把所有模型的一百萬 token 當成同一商品。[OpenRouter 計費說明](https://openrouter.ai/docs/faq)

| 商業模式 | 判斷與可行路線 |
| --- | --- |
| 共享平台上游帳戶，售出自有 API Key 與額度 | 屬於本研究的轉售模式；現行標準條款禁止，需另行協議或更換上游 |
| 把 OpenRouter credits 或帳戶憑證轉交客戶 | credits 不可轉讓；不以此設計商品 |
| 將模型整合進自有應用，例如文件處理或客服 | 條款有描述此情境，但仍須遵守模型條款，並確認產品不落入受禁止的 API 轉售 |
| 客戶自帶 OpenRouter Key，平台提供應用功能 | 可研究 OAuth 接入；客戶直接承擔模型用量，平台收取應用服務費，不宣稱得到通用轉售豁免 |

以上依據為 2026-08-31 更新的條款第 4.4、5 與 7 節。購買 Business 或 Enterprise 方案也不能僅憑方案名稱推定具有轉售權。[OpenRouter 條款](https://openrouter.ai/terms)

OpenRouter Management API 可建立、更新、停用 Key，支援用量限額。這是管理能力，不能當成轉售許可，也不是客戶收款或平台錢包帳本。管理 Key 不可用來呼叫 completions，且權限廣，應僅存放於管理服務。[Management API](https://openrouter.ai/docs/guides/overview/auth/management-api-keys)

## 三條快速建置路線

下列工期為一位熟悉 Docker、Web 與 API 的工程師，在已有 VPS、網域及必要帳戶的情況下估算；不含上游合約、支付商審核與客製法務文件時間。功能可用性以選定版本的驗收結果為準。

| 路線 | 可重用能力 | 自行補足部分 | 技術工期估算 | 適用情境 |
| --- | --- | --- | --- | --- |
| New API | 會員、Key、模型限制、額度、錢包、使用紀錄 | 價格校準、支付設定與驗收、營運規則 | 內部示範半天至 1 天；小規模封閉試用 3 至 7 天；自助收款約 1 至 2 週 | 最快驗證 API 用量平台 |
| LiteLLM 加自製入口 | OpenRouter 轉接、虛擬 Key、預算與用量追蹤 | 會員商店、訂單、儲值帳本、付款與退款 | 閘道約 1 天；具有帳務的最小產品約 1 至 3 週 | 重視客製前台與多上游路由 |
| 自有應用加 OpenRouter OAuth | 用戶授權後取得用戶控制的 Key | 應用功能、登入、Key 保管、服務費收款 | 單一功能原型約 1 至 3 天；收費產品視功能增加 | 先驗證應用價值，降低代墊模型費的負擔 |

New API 官方文件提供部署、channel 與 token 的設定流程；LiteLLM 有 Docker 快速部署與 OpenRouter 轉接；OAuth 文件說明授權碼換取用戶控制的 Key。[New API 快速開始](https://docs.newapi.pro/en/docs)、[LiteLLM 部署](https://docs.litellm.ai/docs/proxy/docker_quick_start)、[LiteLLM OpenRouter 轉接](https://docs.litellm.ai/docs/providers/openrouter)、[OpenRouter OAuth](https://openrouter.ai/docs/guides/overview/auth/oauth)

## New API 為何較快

現行 channel 原始碼含 OpenRouter 類型與預設上游網址。錢包文件列出線上儲值、兌換碼及訂閱，也列出 Stripe 等支付介面。這些可減少自行開發工作，但支付功能須具備完整設定並滿足該版本的支付合規狀態，不能假定安裝後立即能收款。[Channel 原始碼](https://github.com/QuantumNous/new-api/blob/main/constant/channel.go)、[錢包功能](https://docs.newapi.pro/zh/docs/guide/feature-guide/user/wallet)

建議先保留原有介面與署名，用少數已核價模型試用。不要在第一版同時加入自製 UI、代理商分潤、月租無限量及多種類模型端點，這些會放大帳務驗證範圍。

New API 現行 LICENSE 為 AGPLv3；修改後以網路服務提供時涉及對使用者提供相應原始碼的義務。NOTICE 另要求修改版保留指定署名與原專案可見連結。需要閉源修改或不同授權條件時，應先取得合適授權。[LICENSE](https://github.com/QuantumNous/new-api/blob/main/LICENSE)、[NOTICE](https://github.com/QuantumNous/new-api/blob/main/NOTICE)

## LiteLLM 何時值得選

若要自行定義品牌、模型路由與客戶入口，LiteLLM 可作為閘道。虛擬 Key 與預算控制可重用，但成本追蹤不等於客戶預付餘額；充值、扣款、訂單與退款仍須具備一套一致的帳務設計。[LiteLLM 虛擬 Key](https://docs.litellm.ai/docs/proxy/virtual_keys)

其主 LICENSE 對 enterprise 目錄以外內容採 MIT，enterprise 目錄另有授權。選功能時應確認是否涉及商業版，不把所有後台能力一概當成免費。[LiteLLM LICENSE](https://github.com/BerriAI/litellm/blob/main/LICENSE)

只使用 OpenRouter 一個上游時，再加一層 LiteLLM 的價值主要在租戶管理、可觀測性與未來上游切換。若暫時不需要這些能力，自有應用可直接呼叫 OpenRouter，減少維運層數。這是架構取捨，並非效能實測結果。

## 定價與成本試算

建議以金額服務額度銷售，對外明列模型費率與平台服務費；內部保留細分 token 用量及成本。現行 Standard 平台費列為 5.5%，Business 為 8%，Enterprise 可議價。模型價格與平台費要分開計算，實際費用以所用方案和付款頁為準。[OpenRouter 價格](https://openrouter.ai/pricing)

以下為已取得適當轉售授權後的假設情境，不是實際報價：當月模型用量成本基準 US$1,000，全部售出額度皆於當月消耗；以 Standard 的 5.5% 比例作上游費用假設；客戶收款費假設為收入的 3.5% 加每筆 US$0.30，100 筆付款；VPS、備份與監控合計假設 US$50。忽略最低交易費、稅、匯差、退款、拒付、授權費與人力。

| 對模型用量基準加價 | 客戶收入 | 上游支出 | 客戶收款費 | 固定費 | 扣除上述成本後餘額 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 10% | US$1,100 | US$1,055 | US$68.50 | US$50 | −US$73.50 |
| 20% | US$1,200 | US$1,055 | US$72.00 | US$50 | US$23.00 |
| 30% | US$1,300 | US$1,055 | US$75.50 | US$50 | US$119.50 |

計算式為：`餘額 = 客戶收入 − 模型基準 × (1 + 上游費率) − 客戶收入 × 收款費率 − 付款筆數 × 每筆固定費 − 平台固定費`。此情境約須加價 17.6% 才能涵蓋表列成本；20% 加價並不等於 20% 利潤率。

客戶購買但尚未消耗的額度不能直接視為已實現毛利，應保留履約與退款資金。低用量客戶可搭配固定服務費，讓支援成本不完全依賴 token 差價。先用實際付款成本與每客戶使用量替換假設，再決定售價。

## 建議採用順序

1. 確定是售出 API 存取還是售出應用功能，並確認上游允許範圍。
2. 若已具適當上游授權，用 New API 保留原介面建立封閉試用。
3. 先支援文字 Chat Completions，限制為 3 至 5 個已核價模型。
4. 通過串流、併發、付款與對帳驗收後，再開放自助儲值。
5. 客戶需求證實需要品牌入口或特殊帳務後，再評估 LiteLLM 加自製前台。
