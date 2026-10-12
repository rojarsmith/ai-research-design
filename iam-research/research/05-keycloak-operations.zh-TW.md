# Keycloak 營運與故障處理

[回主報告](../README.zh-TW.md)。查核日期：2026-10-12。

營運的目標是讓登入、權限變更與復原都有可驗證的結果。先確認[部署盤點](../templates/current-deployment.zh-TW.md)，再依本手冊安排備份、監控與變更；操作命令和停機時間應以實際版本及部署平台決定。

## 服務目標與責任

指定 IAM 負責人、備援管理員、DB 負責人、應用負責人與事故聯絡方式。IAM 管理員不應共用日常登入帳號；管理動作要能追溯到操作者。緊急帳號需要獨立的保管、存取紀錄與演練，避免上游 IdP 故障後所有管理員一起鎖死。

初始目標可先設登入可用性 99.9%、RPO 15 分鐘、RTO 60 分鐘，但這些是**待確認的設計目標**，不是目前服務的承諾。若只能每天備份，不能宣稱已達 RPO 15 分鐘；需 DB 持續歸檔／PITR 或其他相符機制。

## 定期工作

| 頻率 | 工作 | 完成證據 |
| --- | --- | --- |
| 每日或自動監控 | 登入成功／失敗趨勢、錯誤率、延遲、DB 連線、備份結果、資源用量 | Dashboard／告警及備份完成紀錄 |
| 每週 | 查安全公告與映像更新、檢查異常登入和管理事件、檢查容量與待處理佈建 | 待修補清單、事件調查、重試結果 |
| 每月 | 覆核管理員、Client、角色、群組、service account、redirect 與憑證到期 | 由對應應用負責人確認的清單 |
| 每季或重大變更前 | 隔離還原演練、緊急存取、節點／DB 故障與來源 IdP 中斷 | 實測 RPO／RTO 與驗收結果 |
| 每次變更 | 記錄版本與設定差異、驗收、觀察、回復方案 | 變更單及[驗收清單](06-acceptance.zh-TW.md) |

頻率依使用量、資料變動及可用性要求調整，不把月度演練當成免除上線前還原測試的理由。

## 監控與日誌

health 和 metrics 需要啟用；readiness 決定是否接流量，liveness 判斷程序是否需要重啟。DB 短暫不可用時，readiness 失敗不等於應不斷重啟所有節點。官方容器沒有預裝 curl，探測需從主機／監控器／平台執行，或使用經審查的容器檢查方式。[Health checks](https://www.keycloak.org/observability/health)。

Prometheus/OpenMetrics 從私網管理介面 `/metrics` 蒐集；若要看延遲分布，需啟用對應 histogram。指標名稱與標籤依版本確認，不直接貼舊 PromQL 後就假定有告警。[Metrics](https://www.keycloak.org/observability/configuration-metrics)。

| 監控面 | 建议告警 | 初步處理 |
| --- | --- | --- |
| 使用者路徑 | 合成登入失敗、5xx、p95/p99 延遲持續惡化 | 分辨 proxy、Keycloak、DB、上游 IdP／SMTP |
| JVM／容器 | OOM、持續高 heap／GC、CPU 飽和、restart | 檢查記憶體限制、雜湊負載、尖峰與慢 DB |
| DB | 連線池等待、鎖、磁碟不足、複寫落後 | 查 DB 健康與容量；避免以加節點惡化 DB 壓力 |
| TLS／DNS | 憑證即將到期、DNS 解析或 CA 鏈異常 | 修復續期與名稱；保留 TLS 驗證 |
| 身分流程 | 登入失敗激增、broker 錯誤、佈建積壓 | 查來源狀態、惡意嘗試或配置變更 |
| 備份 | 未按時完成、異地副本缺失、還原演練失敗 | 提高優先級，修復後重做還原 |

上述告警方向是建議；起始閾值以平時基線建立，避免把真實使用者輸入錯誤全部當服務故障。建立專用、最小權限的合成測試帳號，測主要登入路徑，測試秘密放監控平台的秘密儲存。

開啟必要的 user／admin events，集中保存伺服器、代理及資料庫日誌。避免記錄完整 access／refresh token、code、密碼與 secret；訂定個資遮罩、保留期與日誌讀取權限。事件紀錄不可用 DB backup 或 Realm export 的存在代替。[管理與事件](https://www.keycloak.org/docs/latest/server_admin/index.html)。

## 備份與還原

**資料庫備份是主要還原依據，Realm JSON export 只是輔助搬移與設定參考。** 官方說明指出 export 有一致性限制，並不包含全部事件、持久 session、workflow 狀態與撤銷資訊；一致 export 需依文件停用所有節點。[Import and export](https://www.keycloak.org/server/importExport)。

| 保存內容 | 保存方式 |
| --- | --- |
| Keycloak DB | DB 原生一致性備份；按 RPO 保存 WAL／PITR，記錄 DB 版本與 restore 方法 |
| 映像、theme、SPI | 保存固定 digest、建置程式、套件相依與版本 |
| 部署設定 | 保存 Compose／Helm／Operator／GitOps 設定和非秘密參數 |
| 憑證與秘密 | 保存在可復原的秘密管理系統；另列存取責任和緊急保管位置 |
| 外部 IdP／LDAP 設定 | 保存非秘密 mapping、來源位置及憑證取得程序 |
| 事件與稽核 | 集中日誌系統獨立保存，依保留規則管理 |

Realm 金鑰有些保存在 DB，有些來自外部 keystore／provider；依現況確認，不假定 DB 包含所有私鑰。備份與 Realm export 均視為敏感資料，加密、限制權限、留異地副本，不提交 Git。

還原演練步驟：

1. 選定一份備份，記錄備份時間與要還原到的時間。
2. 在隔離網路建立 DB 與相容的 Keycloak 映像，還原 DB 和必要外部檔案／秘密。
3. 阻擋對正式 SMTP、SCIM／同步目標及其他有寫入副作用的來源連線；不讓舊副本產生正式通知或佈建。
4. 以測試 DNS／私有 hosts 和測試 Client 驗證 issuer、登入、MFA、角色、broker、登出。修改還原副本 issuer 後，測試應用要同步改設定。
5. 檢查資料數量與關鍵設定；記錄可復原到何時及耗時，對照 RPO／RTO。
6. 若是正式事故復原，評估舊 session／token 與來源同步是否須重新驗證或撤銷；舊資料回復可能讓已停權者的舊狀態重現。

不要只用「備份檔能下載」判定還原成功。

## 升級與回復

先讀目前版本到目標版本之間的全部 migration notes，確認 DB、theme、SPI、Client library、feature 狀態與 config 變更。研究參考版 26.8.0 不構成要求你立即升級的理由。[Upgrading](https://www.keycloak.org/docs/latest/upgrading/index.html)。

建議先在隔離還原副本測 upgrade；固定新映像、備份舊映像與 DB 恢復點，執行登入／refresh／MFA／broker／角色／停權與還原驗收。正式切換需有維護窗口、流量 drain 和觀察時間。

若資料庫 schema 已遷移，**不可只把映像換回舊版就假定可回復**。依官方支援範圍及實驗結果選擇，必要時停服並還原舊版 DB、舊映像與舊設定；回復點後的帳號與設定變更需補償。Rolling update 只在實際版本／變更組合被確認相容時採用，不混跑任意大版本。[Update compatibility](https://www.keycloak.org/server/update-compatibility)。

26.8.0 與 26.7.0 的 feature 狀態已有差異；例如 SCIM 已從 preview 提升為 supported。採用新功能要確認你的版本，不直接啟用全部 preview。[Features](https://www.keycloak.org/server/features)。

## 帳號與權限生命週期

到職：確認權威來源、建立或佈建帳號、要求必要驗證／MFA、按群組分配最小角色。調職：撤銷舊群組與複合角色，再發新權限並測有效 claims。離職或停權：停用權威來源、同步下游、處理 Keycloak session／refresh／offline session 及應用本地 session，確認再次登入與新取 token 已拒絕。

已發出的 JWT 可能仍被 API 本地驗證接受到過期；停用帳號或按登出不保證所有 API 即時拒絕舊 token。依業務撤權時限，採短 access token、必要的 introspection／狀態檢查或應用撤銷策略，並測實際延遲。離職後仍登入的根因可能是來源同步、broker session、API token 或應用 cookie，必須分層確認。

每個 service account 指定 owner、用途、API scope、secret／金鑰到期與輪替程序。不要讓一般批次工作持有 realm-admin。Client secret 與 realm signing key 是不同秘密，輪替要分開安排。

## 金鑰與憑證輪替

先在測試環境新增新的 signing key，讓驗證端透過 JWKS 得到新舊公鑰，再將新 key 用於簽發；保留舊驗證 key 到舊 token 有效期與合理 cache／時鐘容差結束。驗收未知 `kid` 的受控 JWKS 更新、舊 token 與新 token；不得遇到驗簽問題就關閉驗證。

若私鑰外洩，不能照一般輪替等待舊 token 自然到期；需將泄漏 key 排除信任、撤銷相關 session／token、通知應用更新 cache 與採取強制重新登入。評估每個 API 的實際接受邊界。[OIDC signing key rotation](https://openid.net/specs/openid-connect-core-1_0.html#RotateSigKeys)、[OWASP JWT](https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_Cheat_Sheet.html)。

## 故障處理表

| 症狀 | 先查 | 修正與驗收方向 |
| --- | --- | --- |
| 反覆跳登入／回呼失敗 | 實際 discovery issuer、proxy scheme／host、callback、cookie | 修正不一致；保留 state／nonce 驗證 |
| proxy 後 403／origin 錯誤 | forwarded header、可信 proxy 來源、TLS 模式 | 正確覆寫 header，限制 backend，重測公網與私網 |
| `invalid_redirect_uri` | 實際 callback 與登記值、scheme、port、path | 精確登記，勿以全域 `*` 排除錯誤 |
| `invalid_grant` | code 重用／超時、PKCE、refresh 過期或重用、時鐘 | 發起新流程；確認 library 與 session 設定 |
| API 401 | issuer／audience／簽章／`kid`／過期、是否誤用 ID Token | 檢查 token 種類與驗證器設定 |
| API 403 | Client roles、scope、groups、tenant／資源權限 | 比對業務規則及有效權限，不加 admin 繞過 |
| LDAP 可用但登入失敗 | CA、bind 權限、密碼來源、目錄狀態、帳號映射 | 分別驗來源與本地帳號，避免誤建重複帳號 |
| broker 錯誤／重複帳號 | 上游 issuer、callback、email信任、subject／首次登入 flow | 保留原帳號所有權驗證，再修正 mapping |
| OOM／DB 壓力 | 容器 limit、heap、CPU／hash、DB pool、尖峰 | 確認瓶頸後調整，重測登入與 refresh 負載 |
| SMTP／重設密碼信失敗 | 郵件服務、TLS、寄件域驗證、速率與退信 | 修復寄送與通知，不降低 reset token 保護 |
| 停權後仍可用 | 舊 JWT、offline session、應用 cookie、來源同步 | 分層撤銷並實測生效時限 |
| 升級後主題／外掛壞掉 | 新舊版本、模板、SPI、DB migration | 使用已驗證的回復組合，保留事故證據 |

事故先保留時間、最近變更、錯誤摘要、受影響流程與節點；收集去識別日誌。只處理受影響路徑，不以全站清除資料或重建 DB 作為第一個排查步驟。
