[English](ADR-0013-risk-gate-and-three-path-kill-switch.md) | **繁體中文**

# ADR-0013：在所有模式下完全相同的失效即關閉（fail-closed）風控關卡，以及三路徑緊急停止開關（kill switch）

## 狀態

**提議中（Proposed）** · 2026-10-05 · 範圍：情境 1，並註記情境 2 的風控閘道。Phase 0 對各交易場所撤單與 dead-man 語意的驗證結果將更新本 ADR。

## 背景與問題陳述

每一筆委託在回測、模擬交易與實盤中都必須通過相同的交易前檢查，否則回測結果就是失真的。即使我們自己的行程卡死，所有交易也必須能迅速停止。風控關卡應該是什麼形式？緊急停止開關又該如何運作？

影響因素（[08](../../research/08-risk-security-ops-compliance.zh-TW.md)、[評估紀錄](../../architecture/evaluation.zh-TW.md)）：

- **控制措施可以放在哪裡：**
  - 交易場所原生控制（價格區間、綁定 IP 的金鑰、dead-man 計時器（dead-man timer））；
  - 框架引擎：NautilusTrader `RiskEngine` 會檢查精度、最大名目金額、僅減倉（reduce-only），以及送出／修改委託的速率限制，並具備 `ACTIVE`/`REDUCING`/`HALTED` 狀態；
  - 自訂的行程內函式庫；
  - 行程外的風控閘道（每次網路跳轉約 0.1–2 ms）；
  - 券商或硬體層。

  即使僅供自用，SEC 15c3-5 與 EU RTS 6 仍是實用的檢查清單。
- **審查中發現的緊急停止開關缺口：**
  - Binance 的 `countdownCancelAll` dead-man 計時器僅涵蓋 USDⓈ-M 期貨，且以單一商品為單位，不涵蓋現貨。
  - IBKR 用戶端通常只能撤銷自己送出的委託，除非使用 `reqGlobalCancel`（也會撤銷手動下的委託）或主用戶端 ID（master client ID）。
  - 緊急停止開關與節點共用 IB Gateway。
  - Shioaji 目前沒有已知的 dead-man 功能。
  - 註銷金鑰並不會撤除掛單。
- **經典的失效模式**包括失控迴圈（Knight Capital，2012 年）、失效即開放（fail-open）的例外處理，以及把內部狀態當作事實。
- **維運。** 單人操作者面對 24/7 的加密貨幣交易，不可能一直盯著螢幕。
- **部署位置。** [建議架構](../../architecture/recommended-architecture.zh-TW.md)的 §7 分離拓撲將緊急停止開關放在東京，然而台灣券商金鑰綁定的是住家或台北的 IP，IB Gateway 也在那裡執行。

## 決策驅動因素

- 所有模式的檢查完全相同（回測與實盤一致）。
- 失效即關閉：發生例外時拒絕該委託。
- 停止路徑不依賴策略行程。
- 成本低到一個人也負擔得起；情境 1 的下單路徑上不增加額外的網路跳轉。
- 誠實呈現各交易場所的涵蓋範圍：絕不假設不存在的 dead-man 功能。

## 考慮的選項

1. **節點路徑內的三層防護**（先由 `GuardedStrategy` 透過 `tp_risk` 執行我們失效即關閉的規則包檢查，接著是 NautilusTrader `RiskEngine`，最後是交易場所原生控制），加上虧損斷路器，再加上**三路徑緊急停止開關**：節點、獨立的 `killswitch` 服務、交易場所 dead-man。
2. **僅使用 NautilusTrader `RiskEngine` 與交易場所控制。**
3. **現在就導入行程外風控閘道**（研究 08 中的選項 D）。
4. **僅使用交易場所原生控制。**

## 決策結果

**選定選項：1。** 它以行程內的成本，提供在所有模式下完全相同的完整檢查集合。緊急停止開關在節點卡死時仍能運作。行程外閘道延後至情境 2 再導入，屆時它將帶來多帳戶彙總能力。

### 風控層（所有模式完全相同）

| 層級 | 檢查項目 |
|---|---|
| 1. `GuardedStrategy` → `tp_risk.check(intent, context) -> RiskDecision`（純函式、與引擎無關、**失效即關閉**） | 跳動單位（tick）合規；交易單位與數量單位；漲跌幅限制區間（台灣 ±10%、美國 LULD）；集合競價階段的委託類型限制；處置股與暫停先賣後買的限制；依規則包進行的放空檢查（可否放空與借券確認（locate）、Rule 201 SSR、台灣平盤以下不得放空規則、融券停券期間、信用帳戶資格與額度；[ADR-0012](ADR-0012-security-master-rules-packs-and-calendars.zh-TW.md)）；最大委託數量與名目金額；部位與曝險限額；**各交易場所曝險上限**；保留 20–30% 緩衝的保證金與購買力估算；重複委託與失控偵測；交易時段與商品狀態檢查；能力旗標 |
| 2. NautilusTrader `RiskEngine` | 精度、最大名目金額、僅減倉（reduce-only）、送出／修改委託的速率限制、交易狀態 `ACTIVE`/`REDUCING`/`HALTED` |
| 3. 交易場所原生 | 價格區間、綁定 IP 的僅限交易金鑰、有提供時使用 dead-man 計時器 |

- **虧損斷路器。** 觸及每日虧損上限時，帳戶進入 `REDUCING`。觸及硬性上限時，帳戶進入 `HALTED` 並撤銷所有委託。重設需要記錄原因；對單人操作者而言，還需要一段冷靜期。
- **限額**存放於 git 中的 `config/limits.yaml`。每次變更都是一筆 `LimitChanged` 帳本事件。透過 API 變更限額需要重新驗證並填寫原因。**Telegram 永遠無法調高限額。**
- **所有委託來源共用同一個關卡。** 策略意圖（intent）、手動委託單（`POST /v1/orders`）與已核准的提案（`POST /v1/proposals/{id}/approve`，或以 PIN 執行 Telegram `/approve`）都必須通過第 1 層、WAL 與第 2 層。提案在核准時會重新檢查；若已過期或價格變動超出容許範圍，則予以拒絕。Telegram 可以核准或否決提案，但不能編輯提案、輸入自由格式的委託或調高限額。AI 工具只能建立提案（[ADR-0017](ADR-0017-ai-trust-boundary.zh-TW.md)）。
- **外部委託**（在平台之外下的委託）依循帳戶的外部委託政策，`dedicated` 或 `adopt`（[ADR-0011](ADR-0011-intent-wal-and-hash-chained-ledger.zh-TW.md)）；被接管（adopted）的委託會計入每一項限額與虧損斷路器。
- **投資組合風險（非同步）：** 以新台幣及各幣別計算的即時損益、回撤與曝險；以 250–500 天資料計算的每日歷史 VaR/ES；固定的壓力衝擊情境（指數跳空 −10%、加密貨幣 ±30%、波動率 ×2、利率 +100 bp、新台幣／美元 ±5%、穩定幣脫鉤至 0.90、最大的加密貨幣交易場所餘額全數損失）；投資組合 greeks 與 DV01。當實盤損益偏離回測的蒙地卡羅 95% 區間時，偏移警報會將策略切換為 `REDUCING`。
- **加密貨幣交易場所的對手方風險：** 在 `limits.yaml` 中設定各交易場所的曝險上限（以美元計的最大權益，以及占淨清算價值的比例）；將穩定幣視為商品持有並設定脫鉤警示；交易場所健康狀態警示（暫停提領、儲備證明變動、異常資金費率、API 效能下降）；交易場所失效應變手冊（runbook）；永續合約與選擇權交易場所必須先通過 Phase 0 的台灣居民資格檢查才能納入，且預設以 IBKR 優先（[建議架構](../../architecture/recommended-architecture.zh-TW.md) §3.5）。

### 緊急停止開關：三條路徑

| 交易場所／產品 | 路徑 1：節點 | 路徑 2：`killswitch` 服務 | 路徑 3：交易場所原生 |
|---|---|---|---|
| IBKR | 策略全部撤單並平倉 | 透過 IB Gateway 建立自己的 TWS API 用戶端工作階段（ib_async），使用 **`reqGlobalCancel`** 或主用戶端 ID（於 Phase 0 驗證） | API 委託目前沒有已知機制。手動的最後手段：IBKR 行動 App 或網頁用戶端（見應變手冊） |
| Binance USDⓈ-M 期貨 | 同上 | 自己的僅限交易金鑰；逐商品撤銷所有未成交委託 | `countdownCancelAll`，**對每個有交易的商品個別啟用** |
| Binance 現貨 | 同上 | 同上 | **無。** 交易場所上僅保留營運所需的資金 |
| OKX、Bybit、Deribit、Hyperliquid | 同上 | 同上 | 若有提供，使用 dead-man 或斷線撤單（cancel-on-disconnect）；於 Phase 0 逐產品確認 |
| Shioaji（TWSE/TPEx/TAIFEX） | 同上 | 自己的 Shioaji 工作階段（每個身分證字號允許 5 個），用以列出並撤銷未成交委託 | 目前沒有已知機制 |

- **部署位置。** 緊急停止開關是一個與節點分離的最小化容器，擁有自己的加密貨幣金鑰與自己的 Shioaji 工作階段（[ADR-0008](ADR-0008-key-and-secret-management.zh-TW.md)）。在分離部署中，它**每個站點執行一個執行個體**，因此每個執行個體都使用其券商白名單所允許的固定 IP，且 IBKR 路徑可連到本地的 IB Gateway。
- **觸發方式：** `killswitch` CLI、API 端點、網頁 UI，以及需輸入確認 PIN 的 Telegram `/halt` 與 `/flatten`。應變手冊規定**先撤除掛單，再註銷金鑰**。
- **已知限制（IBKR 注意事項）。** 在 Phase 0 驗證第二個使用者名稱之前，IBKR 的路徑 2 並未獨立於 IB Gateway：路徑 1 與路徑 2 共用 gateway 與 IBKR 登入，因此 gateway 卡死時，只剩下手動的最後手段，也就是 IBKR 行動 App 或網頁用戶端。主報告以及建議架構的 §2、§3.5 在每一處描述緊急停止開關時都會註明此點。

### 影響

**正面**

- 回測包含實盤系統會做出的相同拒絕，因此不會出現來自實際系統會拒絕之委託的隱藏損益。
- 當機或卡住的節點，不會讓加密貨幣交易場所或永豐金證券（SinoPac）上的委託處於無人管理的狀態。
- 各交易場所的涵蓋缺口都明確列出；在沒有 dead-man 的地方，將餘額降到最低。
- 控制措施可對應到 SEC 15c3-5 與 EU RTS 6 檢查清單，有利於日後推出受監管的服務。

**負面**

- 交易前檢查與節點行程同生共死。獨立的緊急停止開關可緩解此問題，但情境 1 中不存在行程外的關卡。
- 緊急停止開關持有額外的認證資訊與第二個 Shioaji 工作階段，擴大了機密的暴露面。
- 透過 `reqGlobalCancel` 進行的 IBKR 緊急撤單，也會撤銷手動輸入的委託。在緊急情況下這可以接受，但操作者必須知道這一點。
- 演練（每月的緊急停止演練與每季的混沌演練）是常態性的職責。

### 確認

- 性質測試（property tests）：關卡絕不放行超出限額的委託，且檢查內部發生例外時會拒絕該委託。API 測試：手動委託單與已核准的提案通過相同的關卡；過期或價格偏移的提案會被拒絕；Telegram 無法調高限額；會突破交易場所曝險上限的委託會被拒絕。
- Phase 0 記錄每個加密貨幣交易場所對台灣居民的資格，上線檢查清單則記錄各交易場所的上限。
- 在 G3 之前，以及之後每月，針對每一個有交易的交易場所與產品，演練全部三條路徑的緊急停止開關。
- Phase 0 驗證 IBKR 撤單語意、各交易場所與產品的 dead-man 支援，以及從第二個工作階段撤單時的 Shioaji 撤單延遲。不支援的項目記錄於此。
- 上線檢查清單項目：限額已審查、虧損斷路器已測試、dead-man 支援已確認或記錄為不存在。

### 重新檢視時機

- **T1 或 T2：** 以行程外風控閘道作為每個帳戶的唯一寫入者；在獨立網路路徑上建立階層式緊急停止開關（策略 → 帳戶 → 交易場所 → 公司），並採四眼原則（four-eyes）重設；日內 VaR/ES 與 greeks 網格。
- 第二個 IBKR 使用者名稱證實可不依賴 gateway → 將緊急停止開關的 IBKR 路徑移至該帳號。
- 交易場所新增或移除 dead-man 支援 → 更新 `capabilities.yaml` 與本表。

## 連結

- [主報告：OMS／風控列、設計原則 8 與緊急停止開關風險](../../README.zh-TW.md)
- [建議架構 §3.5、§7 與 §8.4](../../architecture/recommended-architecture.zh-TW.md)
- [評估紀錄：關注事項 5 與 7；嫁接項目 15](../../architecture/evaluation.zh-TW.md)
- 研究：[08 風險、資安、維運與合規](../../research/08-risk-security-ops-compliance.zh-TW.md) · [04 券商連線](../../research/04-broker-exchange-connectivity.zh-TW.md) · [11 台灣在地化](../../research/11-taiwan-market-localization.zh-TW.md)
- 相關 ADR：[ADR-0006](ADR-0006-broker-connectivity-and-gateway-contract.zh-TW.md) · [ADR-0008](ADR-0008-key-and-secret-management.zh-TW.md) · [ADR-0011](ADR-0011-intent-wal-and-hash-chained-ledger.zh-TW.md) · [ADR-0012](ADR-0012-security-master-rules-packs-and-calendars.zh-TW.md) · [ADR-0017](ADR-0017-ai-trust-boundary.zh-TW.md)
