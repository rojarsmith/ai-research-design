[English](ADR-0011-intent-wal-and-hash-chained-ledger.md) | **繁體中文**

# ADR-0011：下單意圖預寫式日誌（write-ahead log）、雜湊鏈帳本，以及將對帳作為發布阻擋條件

## 狀態

**提議中（Proposed）** · 2026-10-05 · 範圍：情境 1，並註明情境 2 的延伸。

## 背景與問題陳述

系統當機後，我們必須確切知道哪些委託已送出、哪些已成交，以及我們目前持有什麼部位。數個月後，我們也必須能以可察覺竄改（tamper-evident）的方式，證明曾經發生過哪些委託、成交與限額變更。實際發生了什麼，一律以交易場所（venue）為準（source of truth）。

影響因素（[07](../../research/07-system-architecture-messaging.zh-TW.md)、[08](../../research/08-risk-security-ops-compliance.zh-TW.md)、[評估紀錄](../../architecture/evaluation.zh-TW.md)）：

- **NautilusTrader 的持久化是非同步的。** 事件擷取不會等到持久提交（durable commit）完成後才進行派送（dispatch）。因此存在一段空窗期：委託可能已抵達交易場所，但本地端卻沒有任何持久紀錄。
- **Valkey** 在 `appendfsync everysec` 設定下，可能遺失約 1 秒內已確認的寫入；非同步複寫在容錯移轉（failover）時也會遺失寫入。
- **三份提案都沒有完全補上這段空窗。** 提案 B 與 C 提議在每次送出前寫入日誌（journal）；提案 A 則僅依賴對帳。
- **帳本選項：**
  - PostgreSQL 僅能附加（append-only）的事件資料表（具備 ACID、成本低）；
  - KurrentDB（source-available；需要多維運一套系統）；
  - 以 Kafka 作為紀錄系統（system of record）（不支援逐聚合（per-aggregate）的並行控制）；
  - immudb（BSL 1.1）；
  - Amazon QLDB，AWS 已停止提供此服務；
  - 合規模式（compliance mode）下的 S3 Object Lock，已針對 SEC 17a-4、CFTC 與 FINRA 的要求進行評估，可作為 WORM 封存。
- **部位會在沒有委託的情況下變動**：例如透過資金費率結算（funding）、公司行動、選擇權履約與被指派，以及債券配息。

## 決策驅動因素

- 任何委託在離開節點之前，本地端都必須已留有該意圖的持久紀錄。
- 當機或逾時後不得出現重複委託。
- 以近乎零的成本與維運負擔，提供可察覺竄改的稽核軌跡。
- 帳本、參考資料與 MLflow 共用同一個儲存（PostgreSQL 已在技術堆疊之中）。
- 復原時一律以交易場所為準。

## 考慮的選項

1. **依賴 NautilusTrader 的快取持久化，再加上對帳**（提案 A 的原始設計）。
2. **節點本地的意圖 WAL，送出前先執行 fsync，並持續追蹤（tail）寫入 PostgreSQL 僅能附加、以雜湊串鏈的帳本，搭配每晚的 WORM 匯出，並將對帳作為發布阻擋條件。**
3. 以**專用事件儲存**（KurrentDB）或 **Kafka** 作為紀錄系統。
4. 以 **immudb** 作為可察覺竄改的帳本。

## 決策結果

**選定選項：2。** WAL 補上了 NautilusTrader 非同步持久化的空窗期，而在我們的延遲等級（數十到數百毫秒）下，其成本可忽略不計。PostgreSQL 搭配雜湊鏈，就能在我們原本就在運行的儲存中提供竄改證據（tamper evidence）。對帳仍是最終權威。

### 意圖 WAL

- **送出前紀錄。** 在呼叫 `submit_order` 之前，`GuardedStrategy`（或負責手動委託單與已核准提案的 `ManualOrderActor`）會將一筆意圖紀錄附加到節點本地、僅能附加的檔案中，並**對其執行 fsync**，在同一個核心（kernel）週期內使用群組提交（group commit）。
- 每筆意圖紀錄包含 `intent_id`、**標準（canonical）**`client_order_id`、`origin`（STRATEGY、MANUAL 或 PROPOSAL）、`tenant_id`、帳戶、商品、買賣方向、數量、價格、委託類型、有效期限（time in force）、旗標、`RiskDecision` ID，以及紀錄雜湊值。它**不**包含交易場所編碼後的 ID：上游轉接器（adapter）會在 WAL 寫入之後，才於轉接器內部指派該 ID（IBKR 的整數 `orderId` 是在送出時取自 `nextValidId`）。
- **送出後紀錄。** 當轉接器回報交易場所識別碼時，節點會附加一筆 `venue_id_assigned` 紀錄（標準 ID → 交易場所編碼後的客戶端 ID、交易場所委託 ID，以及 IBKR 的 `orderId` 與 `permId`）。這筆紀錄不需要在任何動作之前先完成 fsync，復原程序也從不依賴它。
- `journal` 容器會持續追蹤這兩種紀錄，並以 `OrderIntentRecorded` 與 `VenueIdAssigned` 事件寫入帳本。WAL fsync 延遲與日誌延遲（journal lag）都是設有警示的交易 SLI。
- **異機副本。** 傳送程式（shipper）每隔數秒就會把新的 WAL 區段複製到 S3（或備援節點），使意圖的 RPO 約為 10 秒；PostgreSQL 則持續封存，使帳本的 RPO 在 5 分鐘以內（[建議架構](../../architecture/recommended-architecture.zh-TW.md) §7.1）。

### 帳本

| 面向 | 決策 |
|---|---|
| 儲存 | PostgreSQL 18，資料表 `ledger_event`，僅能附加，並依 `ts_recorded` 按月分割（partition） |
| 不可變性 | 撤銷 `UPDATE` 與 `DELETE` 權限；journal 角色只能執行 `INSERT` |
| 竄改證據 | 每一列都儲存 `prev_hash` 與 `hash = SHA-256(prev_hash ‖ canonical row)`。最後一個雜湊值的每日摘要（digest）存放於異機 |
| 並行控制 | 逐聚合的 `seq` 提供樂觀並行控制（optimistic concurrency）。`event_id` 為 UUIDv7 |
| 酬載（payload） | 事件的 Protobuf JSON 對應格式，每一列都帶有 `tenant_id`（預設為 `'self'`）與 `account_id` |
| 事件類型 | 委託生命週期（包括 `VenueIdAssigned`、`OrderStatusUnknown`、`OrderReconciled` 與 `ExternalOrderAdopted`）、提案（`ProposalCreated`、`ProposalApproved`、`ProposalRejected`、`ProposalExpired`）、成交、`FundingSettled`、`CorporateActionBooked`、`OptionAssigned`、`CouponPaid`、`FxConverted`、`CashTransferred`、`WithholdingTaxBooked`、`BorrowFeeAccrued`、`MarginInterestAccrued`、`TaxLotOpened`/`Closed`（[ADR-0016](ADR-0016-multi-currency-books-tax-lots-and-tax-plugins.zh-TW.md)）、`LimitChanged`、`TradingStateChanged`、`ReconciliationBreak` 等 |
| 投影（projection） | 依帳戶、策略與商品區分的部位；各幣別現金；已實現與未實現損益；手續費與稅金；資金費率應計；未結委託 |
| 封存 | 每晚匯出至**合規模式下的 S3 Object Lock** |
| 數值 | `NUMERIC` 與 `Decimal`，依刻度（scale）量化（[ADR-0003](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.zh-TW.md)） |

### 冪等性與對帳

- 成交依 `(venue, exec_id)` 去除重複。部位由成交與生命週期事件推導而來，絕不由狀態訊息推導。
- 逾時或斷線會使委託在我們的 Shioaji 轉接器與帳本投影中變為 `UNKNOWN`。此狀態透過查詢或對帳來解決，絕不盲目重新送出（[ADR-0006](ADR-0006-broker-connectivity-and-gateway-contract.zh-TW.md)）。對於上游轉接器，NautilusTrader 會讓委託維持在 `SUBMITTED`，並由其在途委託（in-flight order）對帳加以解決；Phase 0 的技術驗證（spike）會逐一針對每個轉接器確認這一點。
- **逐交易場所復原**（表格見[建議架構](../../architecture/recommended-architecture.zh-TW.md) §3.4）。IBKR 不支援依 `orderRef` 查詢，因此復原時會掃描 `reqAllOpenOrders`、`reqExecutions` 與 `reqCompletedOrders`，並比對 `orderRef` 中的標準 ID，或送出後紀錄中的 `permId`。加密貨幣交易場所則依其客戶端 ID 欄位（`origClientOrderId`、`clOrdId`、`orderLinkId`、`label`、`cloid`）查詢。Shioaji 則透過台灣閘道契約（TW gateway contract），依客戶端 ID 或回報資料（ack data）比對來查詢。
- **啟動：**
  1. 從快取與帳本投影重建狀態。
  2. 以對帳模式啟動轉接器，此時**策略維持停止、新委託一律阻擋**。
  3. 以逐交易場所復原程序，解決每一筆尚未進入終止狀態的 WAL 意圖。
  4. 拉取未結委託、自水位線（watermark）起（再減去安全邊際）的成交、部位與餘額。
  5. 將缺漏的成交寫成標記為 `source=RECONCILIATION` 的事件。沒有對應意圖的委託屬於外部委託，依該帳戶的外部委託政策處理（見下文）。
  6. 若出現任何超出容許範圍、且政策無法解釋的差異（break），則維持在 `HALTED` 狀態並呼叫（page）人員處理。
- **盤中：** 每 1–5 分鐘一次。**日終：** 與券商對帳單（broker statements）核對，涵蓋手續費、資金費率、公司行動、選擇權履約與被指派，以及債券配息。
- **任何無法解釋的差異都會使該帳戶停止交易。** 每一筆差異都會連同原因與處置方式一併追蹤。
- **外部委託政策（逐帳戶設定）。** 個人交易者經常會在同一個帳戶上，透過券商 App 手動下單。每個帳戶都必須宣告為 `dedicated`（自動化交易簿擁有專屬的帳戶或子帳戶，因此任何外部委託都視為差異並觸發停止）或 `adopt`（外部委託與成交會由對帳以 `ExternalOrderAdopted` 及 `source=EXTERNAL` 成交的形式，記入 `manual` 交易簿，立即計入限額，並將交易同一商品的所有自動化策略切換為 `REDUCING`，直到擁有者確認為止）。外部成交無法解釋的部位差異仍會觸發停止。透過平台自身委託單（order ticket）下的手動交易則不需要納管（adoption）（[建議架構](../../architecture/recommended-architecture.zh-TW.md) §3.13 與 §5.7）。
- **對帳是首筆實盤交易的發布阻擋條件。** Valkey 在交易主機上以 `appendfsync always` 執行，作為額外的防護措施。

**終止準則（Kill criterion）。** 若 WAL 建置項目落後其階段出口（phase exit）超過三個月，則改為依賴 NautilusTrader 持久化加上對帳，並在新的 ADR 中記錄殘餘風險。

### 後果

**正面**

- 在「送出」與「確認」之間發生的當機，可以透過逐交易場所復原程序復原，且不會產生重複委託（於 Phase 0 針對每個轉接器驗證）。
- 當帳戶採用 `adopt` 政策時，共用帳戶上的手動交易不會再使節點停止。
- 稽核軌跡可察覺竄改、可用 SQL 查詢，且不需額外的運行成本。若日後有需要，WORM 封存也能滿足類似法規要求的資料保存。
- 每一列都帶有 `tenant_id`，意味著日後導入多租戶時不需要進行遷移。
- 同一套投影同時供 UI、風控與損益使用。

**負面**

- fsync 會為每筆委託增加延遲（已量測，在我們的等級下可以接受）。WAL 的輪替與保存必須加以管理。
- 在 NautilusTrader 自身的狀態之外，還存在第二份委託紀錄，兩者必須一致。對帳測試涵蓋這一點。
- 雜湊鏈只有在摘要存放於攻擊者無法觸及之處時，才能偵測竄改。
- IBKR 的復原依賴掃描回呼（callback）而非直接查詢，因此速度較慢，且必須處理 `reqCompletedOrders` 僅涵蓋當日的範圍限制；早於該範圍的意圖，則依成交紀錄與對帳單來解決。
- 在 `adopt` 模式下，錯誤的手動交易會被入帳而不是被阻止；警示與受影響策略的 `REDUCING` 狀態是唯一的防護。
- 事件 schema 必須永久進行版本控管，並搭配 upcaster。

### 確認

- 性質測試（property test）：部位等於成交總和；成交處理具冪等性；雜湊鏈驗證通過。
- 對帳測試（`tests/recon`）會在每次合併時注入人工合成的差異、`UNKNOWN` 委託與外部委託（兩種政策皆涵蓋）。
- Phase 0 技術驗證會針對所使用的每個上游轉接器，驗證在途委託的復原，包括確認 Nautilus IB 轉接器會在 `orderRef` 中攜帶標準 ID。
- 每季一次的完整重建演練：以時間點復原（point-in-time recovery）還原帳本，並在備援節點上重播已傳送的 WAL 區段。
- G3 之前的混沌演練：在委託處理途中執行 `kill -9`，接著重新啟動，並驗證沒有重複委託且帳本完整。
- 上線檢查清單：連續 5 次以上無差異的對帳時段（session）；已量測 WAL fsync 延遲；已設定日誌延遲警示。

### 重新檢視時機

- **T1 或 T2：** 程序外（out-of-process）的委託閘道成為每個帳戶的唯一寫入者，搭配租約（lease）與隔離權杖（fencing token），並在送出前持久化 `PendingNew`。帳本透過交易式 outbox（transactional outbox）發布至 NATS。同步複本讓委託日誌的 RPO ≈ 0。
- **T9：** 逐帳戶的主動—被動（active-passive）架構；新的主節點（leader）在開始交易前先完成對帳。
- 終止準則被觸發。

## 連結

- [主報告：交易紀錄列、結論摘要中的嫁接項與風險](../../README.zh-TW.md)
- [建議架構 §3.4、§3.6、§4.4、§5.2 與 §5.7](../../architecture/recommended-architecture.zh-TW.md)
- [評估紀錄：嫁接項 8、9 與 39；疑慮 12](../../architecture/evaluation.zh-TW.md)
- [提案 B](../../architecture/proposal-B-performance-core.zh-TW.md) · [提案 C](../../architecture/proposal-C-platform-scale.zh-TW.md)
- 研究：[07 訊息傳遞與狀態](../../research/07-system-architecture-messaging.zh-TW.md) · [08 風險與稽核](../../research/08-risk-security-ops-compliance.zh-TW.md) · [04 委託生命週期](../../research/04-broker-exchange-connectivity.zh-TW.md)
- 相關 ADR：[ADR-0003](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.zh-TW.md) · [ADR-0005](ADR-0005-messaging-and-deployment-topology.zh-TW.md) · [ADR-0006](ADR-0006-broker-connectivity-and-gateway-contract.zh-TW.md) · [ADR-0013](ADR-0013-risk-gate-and-three-path-kill-switch.zh-TW.md)
