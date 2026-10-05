[English](ADR-0005-messaging-and-deployment-topology.md) | **繁體中文**

# ADR-0005：即時訊息傳遞與部署形態：行程內匯流排、Valkey 對外輸出、單主機 Compose

## 狀態

**提議中**（Proposed）· 2026-10-05 · 範圍：情境 1。Phase 0 的 Valkey 技術驗證（spike）完成後將更新本 ADR。情境 2 經由觸發條件 T2 與 T9 進入。

## 背景與問題陳述

在交易節點（trader node）內部，NautilusTrader 透過其行程內（in-process）MessageBus，在單一執行緒上分派所有事件。在節點外部，有數個元件需要接收事件，或必須送出命令：

- 日誌寫入器（journal writer），負責建構帳本；
- API 閘道與 UI；
- 警示；
- 控制路徑（停止交易、恢復、平倉、限額變更）。

由此衍生兩個相互關聯的問題：哪一種傳輸機制負責在行程之間傳遞事件？系統又要以何種形態（行程、容器、主機）部署？

考量因素（[07](../../research/07-system-architecture-messaging.zh-TW.md)、[08](../../research/08-risk-security-ops-compliance.zh-TW.md)）：

- **截至 2026-10-05 的訊息傳遞候選方案：**
  - 行程內匯流排；
  - NATS JetStream 2.15.0（Apache-2.0，單一二進位檔）；
  - Kafka 4.3.1（JVM，維運負擔較重）；
  - Redpanda（BSL Community 版）；
  - Redis 8（RSALv2/SSPLv1/AGPLv3）與 Valkey 9.1.2（BSD，Linux Foundation）；
  - Aeron（微秒級路徑；kernel bypass 為付費附加功能）；
  - ZeroMQ（自 2023-10 以來 libzmq 未再發布新版本）。
- **NautilusTrader** 內建以 Redis 為後端的外部串流（external streams）與快取後端（cache backing），所有訊息皆使用 JSON 或 MessagePack。其文件列出的是 Redis 與 PostgreSQL，而非 Valkey，因此 Valkey 相容性尚未經過驗證。其持久化機制並不會等到持久提交（durable commit）完成後才進行分派。
- **持久性。** 採用 `appendfsync everysec` 的 Valkey 可能遺失約 1 秒已確認的寫入，而非同步複寫在容錯移轉（failover）時會遺失寫入。
- **架構風格。** 模組化單體（modular monolith）只在穩定的接縫處拆分，可保持重播的決定性。若第一天就採用微服務，會在委託路徑上增加網路躍點（network hop），並引入分散式故障模式。
- **隔離等級。** L0 是所有功能共用一個節點。**L1** 是每個券商帳戶一個節點。L2 是每個策略與帳戶組合一個節點（這會碰上券商的連線工作階段上限；Shioaji 每個身分證字號允許 5 個工作階段）。L3 則以租戶為單位。
- **託管。** 券商 API 金鑰綁定 IP，因此需要固定的對外 IP（static egress IP）。部分台灣券商可能拒絕雲端 IP。全年無休（24/7）的加密貨幣交易適合 AWS 東京；台灣券商則適合家用伺服器或台北區域。
- **提案 C**（Kubernetes、NATS、OpenBao，第一天就有 13 個可部署單元）在有任何外部使用者之前，每月成本就約 $6k–16k，其可行性評分為 2.5/10。

## 決策驅動因素

- 節點內具決定性的重播，以及回測與實盤的一致性（backtest–live parity）。
- 若引擎本身已支援某種傳輸機制，就不撰寫自訂的橋接程式碼。
- 單人即可負荷的維運負擔；上線後每月成本適中（家用伺服器約 $10–200，單一雲端 VM 約 $200–400；請參閱[主報告](../../README.zh-TW.md)中的成本表）。
- 當機與對帳的影響範圍限縮在單一券商帳戶。
- 任何日後可能以服務形式提供的元件，都採用寬鬆授權（permissive licence）。
- 能以漸進增補的方式成長為團隊平台，而無須重寫。

## 考慮的選項

**訊息傳遞**

1. **節點內使用行程內 MessageBus，節點對外輸出與控制則使用 Valkey 串流**（NautilusTrader 內建的外部串流），並以 NATS JetStream 作為備援方案。
2. 行程內匯流排加上**第一天即採用 NATS JetStream**，透過橋接 actor 串接。
3. 以 **Kafka 或 Redpanda** 作為骨幹。
4. **Aeron 或 ZeroMQ。**

**部署形態**

1. **每個券商帳戶一個模組化單體交易節點（L1），加上少數在穩定接縫處拆分出的行程，於單一 Linux 主機上以 Docker Compose 執行。**
2. **在 Kubernetes 上執行微服務**（提案 C）。
3. 以**桌面一體化部署**（拓撲 A）進行實盤交易。
4. **第一天即採用多區域混合架構**（提案 B）。

## 決策結果

**選定方案：訊息傳遞 1 與部署 1。** NautilusTrader 已支援 Redis 協定的串流，因此若 Valkey 可用，就不需要橋接層。Valkey 維持 BSD 授權，而 Redis 8 則否。單一 Compose 主機是仍能隔離帳戶、機密與廠商行程的最小拓撲。

### 訊息傳遞規則

| 路徑 | 傳輸機制 | 備註 |
|---|---|---|
| 節點內部 | NautilusTrader 行程內 MessageBus | 單執行緒分派；委託路徑上沒有外部躍點 |
| 節點 → 日誌與 API | 基於 **Valkey 9.1** 的 NautilusTrader 外部串流（JSON 或 MessagePack，即引擎本身的序列化格式） | 日誌寫入器與 API 在邊界處將這些訊息轉換為 `proto/` 中的 Protobuf 契約。Valkey 承載的資料維持引擎原生格式 |
| 控制 → 節點 | 每個帳戶一條 Valkey 串流 `tp:ctl:{account_id}`，由節點內的 `ControlActor` 消費 | 命令來自 API 或 Telegram，並在帳本中留存稽核紀錄 |
| 警示 | `tp:alerts` 串流 → 通知器（Telegram/ntfy） | — |
| 引擎快取 | Valkey 作為 NautilusTrader 的快取後端 | 交易主機上的 Valkey 以 **`appendfsync always`** 執行 |
| 委託意圖的持久性 | 不交由匯流排負責 | 節點本地的意圖 WAL，送出前先 fsync（[ADR-0011](ADR-0011-intent-wal-and-hash-chained-ledger.zh-TW.md)） |
| 契約 | `proto/` 中的 Protobuf schema，並於 CI 中執行 `buf breaking` 檢查，涵蓋 API、命令與帳本承載資料 | 傳輸線上先採用 JSON 對應格式；待效能剖析證明有必要時再改用二進位格式 |

**Phase 0 技術驗證。** 驗證 Valkey 作為 NautilusTrader 的 Redis 後端，以及對外輸出的格式。**備援方案：** 改用 PostgreSQL 快取後端，加上透過小型橋接 actor 串接的 NATS JetStream 2.15。

**情境 1 不採用：** Kafka、Redpanda、Aeron、ZeroMQ、RabbitMQ 與 Pulsar。

### 部署規則

| 面向 | 決策 |
|---|---|
| 架構風格 | 每個交易節點為一個模組化單體（六角形核心，hexagonal core）。行程只在穩定的接縫處拆分：券商 sidecar、API、日誌、緊急停止開關（kill switch）與排程器 |
| 隔離 | **L1**：每個券商帳戶一個 NautilusTrader `LiveNode`，節點內的策略以標籤區分。跨帳戶風險以非同步方式彙總 |
| 可部署單元規則 | 新的可部署單元必須擁有自己的擴展、故障或安全邊界；否則就應作為既有單元中的一個模組 |
| 容器（約十個） | `node-<account>`、`ib-gateway`（IB Gateway + IBC）、`shioaji-sidecar`、`journal`、`api`、`killswitch`、`scheduler`、`postgres`、`valkey`、`mlflow`、一個指標／記錄傳送器（shipper），以及使用同一映像檔、按需執行的 `backtest` 工作 |
| 主機 | **單一 Linux 主機，以 Docker Compose 執行，並具備固定對外 IP**：一台配備 UPS、全天候運作的家用迷你電腦，或位於台北（AWS `ap-east-2`，需選擇啟用（opt-in），或 GCP `asia-east1`）或東京（AWS `ap-northeast-1`）的一台 VM。依實測 RTT 選擇，且須先確認台灣券商接受來自雲端 IP 的 API 登入 |
| 存取 | UI 與 API 僅能透過 Tailscale/WireGuard 存取。不對公開網際網路暴露任何服務 |
| 選用拆分 | 在東京另設一台小型 VM 處理 24/7 加密貨幣交易，共用同一本帳本。此時緊急停止開關在每個站點各執行一個實例（[ADR-0013](ADR-0013-risk-gate-and-three-path-kill-switch.zh-TW.md)） |
| 時間與維運 | chrony；每月一次維護時段；Grafana Cloud 免費方案，或 Prometheus + Grafana + Loki |
| 備份與災難復原 | 以 PostgreSQL 持續封存（pgBackRest 或 WAL-G）至 S3，使帳本 RPO 不超過 5 分鐘；意圖 WAL 每隔數秒傳送至主機外；Valkey 視為可重建；bronze 層每晚同步。RTO 不超過 1 小時，方法是以基礎設施即程式碼（infrastructure-as-code）在冷備援主機上重建，而該主機的 IP 已預先登錄於券商允許清單。另備有主機遺失的執行手冊（runbook）、每月還原測試與每季完整重建演練（[建議架構](../../architecture/recommended-architecture.zh-TW.md) §7.1） |
| 研究與回測 | 也可在桌機上執行（拓撲 A：Windows、macOS 或 Linux），但絕不作為實盤主機 |

### 情境 2（觸發條件 T2 與 T9）

- NATS JetStream 成為行程間匯流排，subject 為 `tp.{tenant}.{account}.orders.{event}`、`tp.{tenant}.{account}.ctl` 與 `tp.md.{venue}.{instrument}`；每個租戶各有一個 NATS 帳戶（account），並以 leaf node 連接台灣站點與邊緣連接器。
- 委託／風控閘道移至行程外，作為每個帳戶的單一寫入者（single writer），並搭配租約（lease）與 fencing token。
- 每個交易場所帳戶一個閘道行程。Kubernetes 1.35+ 承載無狀態服務，而交易節點仍留在固定配置（pinned）的 VM 上。
- 觸發 T9 時：每個帳戶採主動-被動（active-passive），絕不對同一個帳戶採主動-主動（active-active）。

### 後果

**正面**

- 委託路徑上沒有網路躍點，因此重播保持決定性。
- 若技術驗證通過，就不需要自訂橋接層。備援方案規模小且已知。
- 整個系統在一台機器上執行，只需一個固定 IP 供券商允許清單登錄；上線後每月成本約為家用伺服器 $10–200（另加硬體）或單一雲端 VM $200–400。
- 當機或對帳中斷只侷限於單一帳戶。
- 訊息傳遞元件皆採寬鬆授權（Valkey 為 BSD、NATS 為 Apache-2.0），因此日後推出服務時，不會承接 Redis 或 Redpanda 的授權陷阱。

**負面**

- 單一主機即為單點故障，且 WAL、Valkey、帳本與資料湖共用其磁碟。交易場所的 dead-man 計時器、自動平倉規則、呼叫通知（paging）、UPS、主機外封存、冷備援主機與重建演練可部分彌補；但主機遺失仍可能造成最多一小時的交易中斷。
- `appendfsync always` 會增加 Valkey 的寫入延遲（以我們的層級而言可接受）。真正的持久性保證仍是 WAL。
- 在技術驗證完成之前，Valkey 與 NautilusTrader 的相容性仍未經驗證。
- 存在兩套序列化世界（Valkey 上的引擎 JSON/MessagePack，以及 API 與帳本的 Protobuf），因此邊界轉換器必須經過測試。
- 日後改用 NATS 意味著要重寫對外輸出與控制的管線，但不需重寫核心（kernel）、策略或帳本。

### 確認

- Phase 0 技術驗證的結論記錄於此：Valkey 作為 NautilusTrader 快取與串流後端，以及對外輸出的訊息格式。
- G3 之前的混沌演練（chaos drill）：委託進行中執行 `kill -9`、Valkey 重新啟動、網路分割（network partition）、PostgreSQL 還原。
- Compose 健康狀態儀表板，加上交易 SLI：日誌延遲（journal lag）、重新連線、時鐘偏移與 WAL fsync 延遲。
- 審查關卡會對任何新容器套用可部署單元規則。

### 何時重新檢視

- **T2：** 4–5 名以上工程師，或超過約五個交易節點或帳戶 → NATS、每個交易場所各自的閘道、行程外的風控閘道、OpenBao，以及用於無狀態服務的 Kubernetes。
- **T3：** 需要僅支援 Windows 的券商 → Windows 閘道 VM（[ADR-0006](ADR-0006-broker-connectivity-and-gateway-contract.zh-TW.md)）。
- **T9：** 資金無法承受數小時的停機 → 採用具 fencing 的主動-被動架構與第二個區域。
- Valkey 技術驗證失敗 → 改用 NATS 備援方案。

## 連結

- [主報告：訊息傳遞與部署相關列；觸發條件 T2、T3 與 T9](../../README.zh-TW.md)
- [建議架構 §2、§5.1 與 §7](../../architecture/recommended-architecture.zh-TW.md)
- [評估紀錄：嫁接項目（grafts）4、24 與 39；疑慮 6 與 12；§4.3 中被否決的元素](../../architecture/evaluation.zh-TW.md)
- [提案 C](../../architecture/proposal-C-platform-scale.zh-TW.md)
- 研究：[07 系統架構與訊息傳遞](../../research/07-system-architecture-messaging.zh-TW.md) · [08 風險、安全與維運](../../research/08-risk-security-ops-compliance.zh-TW.md)
- 相關 ADR：[ADR-0006](ADR-0006-broker-connectivity-and-gateway-contract.zh-TW.md) · [ADR-0011](ADR-0011-intent-wal-and-hash-chained-ledger.zh-TW.md) · [ADR-0013](ADR-0013-risk-gate-and-three-path-kill-switch.zh-TW.md)
