# IAM 上線與變更驗收清單

[回主報告](../README.zh-TW.md)。制定日期：2026-10-12。

在測試環境執行安全與故障情境，使用合成帳號與資料。每項記錄版本、Client、測試時間、預期／實際結果與負責人；標記通過、失敗或有理由的不適用。以下全部是待執行的驗收，並未在你的現有服務上測試。

## 登入與 Token

- [ ] Discovery 的 issuer 與應用預期完全一致；正式端點 HTTPS、憑證鏈有效。
- [ ] Code + PKCE S256 成功；錯誤 verifier、重用 code、錯誤／缺失 state 或 nonce 按流程拒絕。
- [ ] 未登記 callback 被拒絕；production Client 不接受測試域與任意萬用回呼。
- [ ] SPA 不含 secret；瀏覽器儲存、前端日誌與錯誤追蹤不意外暴露 token。
- [ ] API 拒絕錯誤 issuer、錯誤 audience、過期／尚未有效、遭竄改、未允許演算法及未知不可信 key 的 token。
- [ ] API 不誤接受 ID Token；未授權為 401，已驗證但無權限的操作為 403 或符合產品的拒絕行為。
- [ ] Access token 到期可正常 refresh；過期／撤銷／不允許重用的 refresh 被拒絕。
- [ ] 登出清除應用 session，並按設計終止 SSO；多應用與前／後通道 logout 各測。
- [ ] Third-party cookie 受限的瀏覽器仍有可用登入路徑，不因 silent SSO 失敗卡死。

## MFA 與帳號

- [ ] MFA 登記、登入、遺失裝置與復原均經驗證；管理員政策獨立覆核。
- [ ] 密碼重設／驗證 email 的鏈接過期、重用與錯誤來源被拒絕。
- [ ] Brute-force 與上游／入口防護正常；不把大規模鎖死合法帳號當成唯一保護方式。
- [ ] Broker 首次登入、既有帳號連結與相同 email 不同來源 subject 的情境均安全。
- [ ] 停用來源帳號後，重新登入、新 token、refresh、舊 JWT 與應用 cookie 分別確認生效時限。
- [ ] SCIM 建立／改名／更新／停用／群組移除／重送／分頁／錯誤重試均按目標方向實測。

## 授權與隔離

- [ ] `reader` 不能執行 `editor` 動作；另一個 Client 同名角色不誤認為本 API 角色。
- [ ] 移除直接角色、群組與複合角色後，有效權限按預期變更。
- [ ] Tenant A 使用者修改 URL、resource ID、request body 的 tenant 或 header，均不能讀寫 Tenant B 資料。
- [ ] M2M 僅能呼叫所需操作，不能使用管理 API 或存取員工／其他客戶資料。
- [ ] 代理保護的舊 Web 後端不能繞過 proxy 直接訪問；外部輸入的身分 headers 被移除／覆寫。

## 架設與營運

- [ ] 8080／8443 backend、9000 management、DB 與叢集 ports 依拓撲限制來源，公網不能繞過代理。
- [ ] 公開 hostname 不能繞過管理入口 ACL 存取 Admin API；別名設定本身不當作隔離。
- [ ] Ready 失敗時 LB 不導流；Live 與 Ready 的處理不同；重啟不產生無限循環。
- [ ] 監控包含使用者路徑與主要依賴；告警實際到達指定負責人。
- [ ] 異常登入與管理變更有日誌，密碼、完整 token 與 secret 不外洩，保留與讀取政策有效。
- [ ] 固定映像與設定可重新建置；DB 及秘密保存位置已確認。
- [ ] 從備份在隔離環境還原，驗證帳號、MFA、Client、角色與必要 key；實測 RPO／RTO。
- [ ] 升級及回復的 DB／映像／設定組合已演練，不只做 image downgrade。
- [ ] 新舊 signing key、Client secret、TLS 與上游憑證輪替均按計畫實測。
- [ ] 若有 HA 要求，節點退出、DB failover、快取網路異常及來源 IdP 故障都測過。

## 每次變更紀錄

| 欄位 | 填寫內容 |
| --- | --- |
| 變更 | 目標版本、Client／flow／mapping／proxy 差異 |
| 復原點 | DB 備份／PITR 時間、舊映像、秘密版本 |
| 驗收 | 以上情境及新增業務場景的結果 |
| 切換與觀察 | 時段、負責人、延遲／錯誤／登入基線 |
| 回復條件 | 哪個錯誤、影響範圍或時間觸發回復 |
| 回復程序 | DB、映像、設定與流量如何恢復及資料補償 |

安全驗收依據：[RFC 9700](https://www.rfc-editor.org/rfc/rfc9700)、[OWASP REST Security](https://cheatsheetseries.owasp.org/cheatsheets/REST_Security_Cheat_Sheet.html)。部署與復原依據：[Keycloak proxy](https://www.keycloak.org/server/reverseproxy)、[health](https://www.keycloak.org/observability/health)、[import/export](https://www.keycloak.org/server/importExport)、[upgrading](https://www.keycloak.org/docs/latest/upgrading/index.html)。
