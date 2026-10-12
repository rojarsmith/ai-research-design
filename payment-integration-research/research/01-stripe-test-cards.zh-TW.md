[English overview](01-stripe-test-cards.md) | **繁體中文** | [回研究入口](../README.zh-TW.md)

# Stripe 測試信用卡與驗收情境

查核日期：2026-10-12（Asia/Taipei）。

Stripe 測試卡用來模擬付款結果，不會移動真實資金。卡號只是測試輸入；軟體是否正確更新訂單、會員權限與帳務，還需要驗證後端和 Webhook 的處理。

指定文章為 Karbon 的 [The Beginner’s Guide to Stripe Test Cards: Validate Your Checkout](https://www.karboncard.com/blog/test-card-stripe)，作者 Swati Saraf；可讀頁面未顯示明確發表日期。文章涵蓋成功付款、拒付、風控、國別卡與 3D Secure，並提及退款、爭議款和訂閱。本資料保留其範圍，卡號與行為以 [Stripe 官方測試文件](https://docs.stripe.com/testing) 為依據，不收錄文章的商業推廣。

## 測試環境與輸入欄位

在 Dashboard 帳戶選單選擇 Sandboxes；Stripe 目前建議新整合使用 general sandbox。既有整合若依賴 test mode sandbox，依其適用情況使用。只切換 Dashboard 顯示資料，不會自動改掉網站或伺服器的 API Key。[Sandboxes](https://docs.stripe.com/sandboxes)

| 項目 | 使用方式 |
| --- | --- |
| 前端金鑰 | 使用該測試環境的 `pk_test_…` |
| 後端金鑰 | 使用該測試環境的 `rk_test_…` 或 `sk_test_…`，依整合支援與最小權限需求設定 |
| Webhook secret | 使用測試端點對應的 signing secret；它與 API Key 是不同憑證 |
| 有效期限 | 未來有效日期，例如 `12/34`；過期卡情境仍可填未來日期，由特殊卡號模擬拒付 |
| CVC | 一般卡任意 3 位，例如 `123`；American Express 任意 4 位，例如 `1234` |
| 地址與郵遞區號 | 按表單要求填寫；測 AVS 或郵遞區號失敗時，要有對應欄位輸入 |

金鑰與測試／正式物件要屬於同一環境；非公開金鑰保存在後端，不能放進前端或 Git。[API keys](https://docs.stripe.com/keys)

測試卡只適用 Stripe 測試環境，其他支付服務使用各自的 Sandbox 資料。自動化測試優先使用官方測試 PaymentMethod（例如 `pm_card_visa`），手動付款頁測試才輸入卡號。[測試方式](https://docs.stripe.com/testing#how-to-use-test-cards)

## 成功付款卡號

以下是原文七個品牌的測試資料；有效期限與 CVC 依上一節填寫。

| 品牌 | 測試卡號 | CVC 位數 |
| --- | --- | --- |
| Visa | `4242 4242 4242 4242` | 3 |
| Mastercard | `5555 5555 5555 4444` | 3 |
| American Express | `3782 822463 10005` | 4 |
| Discover | `6011 1111 1111 1117` | 3 |
| JCB | `3566 0020 2036 0505` | 3 |
| Diners Club | `3056 9300 0902 0004` | 3 |
| UnionPay | `6200 0000 0000 0005` | 3 |

來源：[Stripe 品牌測試卡](https://docs.stripe.com/testing#cards)。卡號代表指定的成功付款模擬情境，不保證錯誤 API 設定、金額或其他整合問題也能成功。

## 拒付與格式錯誤

| 測試卡號 | 情境 | Error code | Decline code |
| --- | --- | --- | --- |
| `4000 0000 0000 0002` | 一般拒付 | `card_declined` | `generic_decline` |
| `4000 0000 0000 0069` | 卡片過期 | `expired_card` | 不適用 |
| `4000 0000 0000 9995` | 餘額不足 | `card_declined` | `insufficient_funds` |
| `4000 0000 0000 9979` | 失竊卡 | `card_declined` | `stolen_card` |
| `4000 0000 0000 9987` | 遺失卡 | `card_declined` | `lost_card` |
| `4242 4242 4242 4241` | 卡號檢查失敗 | `incorrect_number` | 不適用 |
| `4000 0000 0000 0127` | 補充：CVC 錯誤拒付 | `incorrect_cvc` | 不適用 |

來源：[Stripe 拒付測試](https://docs.stripe.com/testing#declined-payments)。最後一列是官方補充；`4242…4241` 可先在前端因格式檢查遭攔截，不能期待每次都產生後端付款事件。CVC 測試需提供 CVC。

客戶提示須區分可修正欄位與敏感拒付原因。卡號、期限、CVC 可引導重新輸入；遺失、失竊與疑似詐欺等原因依 Stripe 指引使用一般拒付提示，詳細資訊留在受限的營運紀錄。[拒付訊息指引](https://docs.stripe.com/declines/codes)

## 風控與驗證欄位

| 測試卡號 | 官方情境 | 判讀條件 |
| --- | --- | --- |
| `4000 0000 0000 0010` | 地址第一行及郵遞區號檢查失敗 | 依 Radar 規則可能封鎖 |
| `4000 0000 0000 0036` | 郵遞區號檢查失敗 | 要提供郵遞區號；依 Radar 規則可能封鎖 |
| `4000 0000 0000 0101` | CVC 檢查失敗 | 要提供 CVC；依 Radar 規則可能封鎖 |
| `4000 0000 0000 4954` | `highest` 風險 | 是否封鎖依 Radar 設定 |
| `4100 0000 0000 0019` | 一律被 Radar 封鎖 | 預期付款被阻擋 |

來源：[Stripe 風控測試](https://docs.stripe.com/testing#fraud-prevention)。`0101` 是檢查結果失敗；要測確定回傳 `incorrect_cvc` 的拒付，使用上一節的 `0127`。

## 國別測試卡

| 模擬發卡國家 | 品牌 | 正確卡號 | 收錄說明 |
| --- | --- | --- | --- |
| 印度 | Visa | `4000 0035 6000 0008` | 原文收錄 |
| 英國 | Visa | `4000 0082 6000 0000` | 原文收錄 |
| 阿拉伯聯合大公國 | Visa | `4000 0078 4000 0001` | 原文收錄 |
| 日本 | JCB | `3530 1113 3330 0000` | 原文收錄 |
| 巴西 | Visa | `4000 0007 6000 0002` | 原文數字排列錯誤，依官方修正 |
| 墨西哥 | Visa | `4000 0048 4000 8001` | 原文卡號少一位，依官方修正 |
| 台灣 | Visa | `4000 0015 8000 0008` | 官方補充 |

來源：[Stripe 國別卡](https://docs.stripe.com/testing#international-cards)。發卡國家模擬不等於客戶所在地、網站語言、付款幣別或商家開戶國家；台灣測試卡也不代表台灣公司可直接開設 Stripe 收款帳戶。匯率與地區支付方式需另設測試條件。

## 3D Secure 驗證與卡片保存

On-session 指客戶正在操作付款；off-session 指客戶未在場、系統使用先前保存的付款資料扣款。

| 測試卡號 | 官方行為 |
| --- | --- |
| `4000 0025 0000 3155` | On-session 需要驗證；off-session 未完成未來使用設定時需要驗證，設定完成後可免驗證 |
| `4000 0027 6000 3184` | 每次交易都需要驗證，即使已完成保存設定 |
| `4000 0038 0000 0446` | 已模擬完成 off-session 設定；off-session 成功，單次及其他 on-session 付款仍需驗證 |
| `4000 0082 6000 3178` | 單次付款需要驗證；驗證成功或已完成設定後，付款仍以 `insufficient_funds` 拒付 |

來源：[Stripe 3D Secure 測試](https://docs.stripe.com/testing#regulatory-cards)。3DS 驗證成功和扣款成功是兩個不同結果；應在實際整合的前端測驗證流程，直接從 Dashboard 建立付款不會呈現 3DS 重新導向。

## 原文需要修正或補足的內容

| 原文項目 | 核對結果 |
| --- | --- |
| 墨西哥 `4000 0484 0008 001` | 少一位；正確為 `4000004840008001` |
| 巴西 `4000 0076 0000 0002` | 數字排列錯誤；正確為 `4000000760000002` |
| 3DS `4000 0276 0000 3184` | 數字排列錯誤；正確為 `4000002760003184` |
| 3DS `4000 0380 0000 0446` | 數字排列錯誤；正確為 `4000003800000446` |
| 3DS `4000 0826 0000 3178` | 數字排列錯誤；正確為 `4000008260003178` |
| `0101` 標為 CVC 錯誤 | 應區分 CVC 檢查失敗與 `0127` 的 CVC 錯誤拒付 |
| `3178` 標為驗證因餘額不足而失敗 | 可成功完成驗證，但付款仍因餘額不足被拒絕 |
| `3155` 說明未區分交易方式 | 完成設定可影響 off-session；on-session 仍需驗證 |
| 切換 Dashboard 測試資料後所有付款都成為測試 | 應另外核對應用程式使用的金鑰、物件和 Webhook 環境 |
| 顯示每種拒付的詳細原因 | 遺失、失竊及詐欺等情境應使用一般拒付提示 |

以上對照：[原文](https://www.karboncard.com/blog/test-card-stripe)、[官方測試](https://docs.stripe.com/testing)、[API keys](https://docs.stripe.com/keys)、[拒付訊息指引](https://docs.stripe.com/declines/codes)。

## 退款與爭議款補充

原文只有提及退款與爭議款用途；以下為官方補充案例。

| 測試卡號 | 情境 | 後端應觀察的結果 |
| --- | --- | --- |
| `4000 0000 0000 7726` | 付款成功後發起非同步退款 | Refund 由 `pending` 轉 `succeeded`，收到 `refund.updated` |
| `4000 0000 0000 5126` | 付款成功後發起退款，稍後失敗 | Refund 由 `succeeded` 轉 `failed`，收到 `refund.failed` |
| `4000 0000 0000 0259` | 預設帳戶設定下，付款後產生詐欺爭議 | 觀察爭議款處理；3DS 驗證可能提供保護，應留意該測試流程 |

來源：[退款測試](https://docs.stripe.com/testing#refunds)、[爭議款測試](https://docs.stripe.com/testing#disputes)。

## 軟體整合驗收清單

以下是待執行的驗收案例，尚未代表任何現有系統已通過。

| 案例 | 輸入或操作 | 驗收目標 |
| --- | --- | --- |
| 基本成功付款 | Visa `4242…4242` | 金額、幣別、訂單歸屬正確；付款確認後只交付一次 |
| 拒付 | `0002`、`9995`、`0069` | 保留可重試狀態，未付款不開通服務 |
| 欄位錯誤 | `4242…4241`、CVC 拒付卡 `0127` | 顯示可修正提示，不誤標已付款 |
| 風控 | `4954`、`0019`、`0101` | 結果符合該環境的 Radar 設定；必要欄位確實有傳送 |
| 3DS | `3155`、`3184`，完成或取消驗證 | 正確處理返回流程及未完成付款；另用 `3178` 測驗證成功後拒付 |
| 保存卡片後扣款 | `3155`、`0446`，分別測 on-session 和 off-session | 客戶在場與不在場的流程都符合產品需求 |
| 重複通知 | 重送相同事件，並重複觸發同一訂單的處理 | 不重複出貨、開通或增加儲值額度 |
| 通知亂序與延遲 | 改變事件處理順序，暫停後恢復接收 | 不依到達順序推斷最終狀態；可以補查物件並恢復處理 |
| 退款 | 一般退款、`7726`、`5126` | 分辨待處理、成功、失敗；額度與權限依產品規則調整 |
| 訂閱 | Test clocks 推進試用與續費，模擬付款失敗 | 發票、訂閱狀態與服務期限一致 |

Stripe Webhook 可能重送且不保證順序，接收端要驗證簽章並處理重複事件。設計上另以訂單或付款物件約束業務操作，避免不同事件造成重複交付。[Webhook 文件](https://docs.stripe.com/webhooks)

Checkout 的交付應使用伺服器確認的付款狀態，不能只依瀏覽器返回成功頁；延遲支付也必須等到付款成功才交付。[Checkout 交付文件](https://docs.stripe.com/checkout/fulfillment.md?payment-ui=stripe-hosted)

訂閱測試還需要時間推進、發票事件、試用結束及續費情境，不能只靠成功卡號。[Billing 測試文件](https://docs.stripe.com/billing/testing)

## 查證來源

| 來源 | 用途 |
| --- | --- |
| [Karbon 指定文章](https://www.karboncard.com/blog/test-card-stripe) | 原始收錄範圍與差異對照 |
| [Stripe Testing](https://docs.stripe.com/testing) | 卡號、模擬行為、測試 PaymentMethod |
| [Stripe Sandboxes](https://docs.stripe.com/sandboxes) | 測試環境選擇 |
| [Stripe API keys](https://docs.stripe.com/keys) | 前後端金鑰與環境區隔 |
| [Stripe Decline codes](https://docs.stripe.com/declines/codes) | 拒付提示的對外呈現 |
| [Stripe Webhooks](https://docs.stripe.com/webhooks) | 簽章、重送與順序 |
| [Stripe Checkout fulfillment](https://docs.stripe.com/checkout/fulfillment.md?payment-ui=stripe-hosted) | 付款確認與交付 |
| [Stripe Billing testing](https://docs.stripe.com/billing/testing) | 訂閱與 Test clocks |

來源查核與卡號整理已完成；實際整合驗收仍須在目標軟體的 Stripe 測試環境執行。
