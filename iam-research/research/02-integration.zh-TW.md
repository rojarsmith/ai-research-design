# 應用與企業身分整合

[回主報告](../README.zh-TW.md)。查核日期：2026-10-12。

現有應用先與 Keycloak 建立一個穩定的 issuer 關係，再讓 Keycloak 依需求銜接企業目錄或外部 IdP。若目標應用本身已有合適的 IAM，直接串接也可以；每加一層 broker 都會增加帳號映射、登出與停權責任。

## 標準與資料

| 名詞 | 用途 | 常見誤用 |
| --- | --- | --- |
| OAuth 2.0 | 讓 Client 以限定權限取得資源 | 單憑 access token 就自創「已登入的是誰」判斷 |
| OIDC | 驗證登入者，傳遞 ID Token 與 claims | 把 ID Token 當作自家 API 的通行憑證 |
| SAML 2.0 | 企業與舊應用 SSO | 僅匯入 metadata，未驗證簽章、Audience、Recipient 與時效 |
| LDAP／AD | 目錄、帳號與群組來源 | 誤認 Keycloak 的 LDAP federation 會讓 Keycloak 成為 LDAP Server |
| SCIM | 建立、更新、停用使用者與群組 | 把 SSO／首次登入建帳當作可靠離職同步 |
| JWT／JWKS | token 格式／驗證用公鑰集合 | 把 decode 當驗簽，或任意信任 token 裡提供的金鑰網址 |

OIDC 的身分鍵使用可信 issuer 與 `sub` 的組合；email、帳號顯示名稱可能變更，也不保證跨 IdP 唯一。[OIDC Core](https://openid.net/specs/openid-connect-core-1_0.html)。API 在接收 token 的邊界核對簽章、允許演算法、issuer、audience 與時間，並在每個操作執行授權。[OWASP REST Security](https://cheatsheetseries.owasp.org/cheatsheets/REST_Security_Cheat_Sheet.html)。

## 依應用選流程

| 應用 | Client 與流程 | Token 與權限落點 |
| --- | --- | --- |
| React／Vue／Angular SPA | Public Client；Authorization Code + PKCE S256；Standard Flow 開啟，Client authentication 關閉 | 不放 client secret；token 優先存記憶體；API 自己驗證 access token |
| Next.js／一般伺服器 Web／BFF | Confidential Client；Code + PKCE；伺服器換 token | 瀏覽器拿 HttpOnly、Secure 的 session cookie；伺服器保管 token；評估 SameSite 與 CSRF |
| Spring Boot／ASP.NET Core／Node／Python API | Resource Server；以 framework 的 OIDC/JWT 驗證能力接 discovery/JWKS | 固定可信 issuer 與 API audience，映射角色並檢查資料範圍 |
| 手機／桌面程式 | Public Client；系統瀏覽器 Code + PKCE；合規 callback | 不內嵌長期 secret；token 存 OS 保護儲存；驗證 callback 綁定 |
| 無方便瀏覽器的 CLI／設備 | 目標版本支援且合適時用 Device Authorization Grant | 顯示可信登入網址與短碼；處理輪詢間隔、過期與取消 |
| 排程／服務對服務 | Confidential Client；Client Credentials 或合適的工作負載憑證 | 每個服務獨立身分、scope 與憑證；不使用員工密碼 |
| Grafana／GitLab／Nextcloud 等 | 依該產品版本的原生 OIDC/SAML 文件接入 | 先查支援版本、付費限制、回呼與角色 mapping；每個應用獨立 Client |
| 沒有原生 SSO 的內部 Web | OIDC reverse auth proxy／authentik Proxy Provider | 阻擋直接訪問後端，重寫身分 header；登入門禁外仍需業務授權 |

公開 Client 必須使用 PKCE；新整合採 Code + PKCE，不採 ROPC／Password Grant，避免 Implicit 直接在前端回傳 token。回呼 URI 精確登記。[RFC 9700](https://www.rfc-editor.org/rfc/rfc9700)。Native app 採系統瀏覽器的指引見 [RFC 8252](https://www.rfc-editor.org/rfc/rfc8252)。

## Keycloak Client 的設定範例

以下是設計範例，需換成實際應用網址；`Client` 是信任與設定登記，不會建立應用程式。

| 項目 | SPA `portal-spa` | BFF `portal-web` | API `orders-api` | M2M `billing-worker` |
| --- | --- | --- | --- | --- |
| Client authentication | Off | On | 不需登入；依用途配置 | On |
| Standard Flow | On | On | Off | Off |
| Implicit Flow | Off | Off | Off | Off |
| Direct Access Grants | Off | Off | Off | Off |
| Service Accounts | Off | Off | Off | On |
| PKCE | S256 強制 | S256 | 不適用 | 不適用 |
| Redirect | `https://portal.example.com/callback` | `https://portal.example.com/signin-oidc` | 無 | 無 |
| Web Origins | `https://portal.example.com` | 依前端實際需求 | 不因 API Client 而自動設定跨域 | 無 |
| 權限 | 僅需要的 client scopes | 僅需要的 client scopes | 定義 `reader`、`editor` 等應用角色 | 僅批次工作所需角色／scope |

SPA 的 Redirect 與 Web Origins 要分開設定；Origin 沒有 `/callback` 路徑。API 自己的 CORS 也要設定，Keycloak Web Origins 不會替你的 API 設 CORS。

用 Audience mapper／client scopes 讓呼叫 `orders-api` 的 access token 包含該 API 所要求的 `aud`，再由 API 驗證；不能以 `azp` 代替 audience。`realm_access.roles` 與 `resource_access[client-id].roles` 是不同角色位置；claim 是否出現在 token 要看 scope 與 mapper 配置。處理 `orders-api:reader` 時，不要誤接受另一個 Client 的 `reader`。

驗收時先取得一顆真實測試 token，在本機確認必要 claims；別把 token 貼到公開解碼網站。禁用 Full Scope Allowed 或縮小 mapper/scopes 前，先測應用實際所需 claims，避免一次刪掉所有權限資訊。

## 找到正確的端點

Keycloak 預設路徑可從下列 discovery 取得，正式環境應以實際 issuer 為準；如果保留 `/auth` context path，就應包含該路徑。[OIDC 端點文件](https://www.keycloak.org/securing-apps/oidc-layers)。

```text
Issuer:    https://sso.example.com/realms/company
Discovery: https://sso.example.com/realms/company/.well-known/openid-configuration
Auth:      /realms/company/protocol/openid-connect/auth
Token:     /realms/company/protocol/openid-connect/token
JWKS:      /realms/company/protocol/openid-connect/certs
Logout:    /realms/company/protocol/openid-connect/logout
```

應用設定 issuer，不要手填互不一致的 Auth／Token／JWKS 網址；library 能讀 discovery 時交給它處理。登出使用支援的標準 logout 流程，並清除應用本地 session；SSO session 與業務 session 要分別驗收。

## 企業與外部 IdP

| 來源 | 設定方向 | 驗收重點 |
| --- | --- | --- |
| AD／LDAP | Keycloak User Federation 連向目錄，起初評估只讀模式與最小 bind 權限 | LDAPS／可信 CA、同步排程、群組 mapping、來源帳號停用與殘留 session |
| Entra／Okta／另一套 Keycloak | 在上游登記代表 Keycloak 的 OIDC/SAML Client；Keycloak 加 Identity Provider | 精確使用 Keycloak 顯示的 broker callback；issuer、憑證、claims、首次登入與帳號連結 |
| Google／GitHub 等社群 IdP | 在來源平台註冊 OAuth/OIDC 應用，再接 Keycloak broker | 社群 provider 類型、回呼、scope、email 信任與帳號所有權 |
| Keycloak → Auth0／Cognito／Identity Platform | 目標平台把 Keycloak 當上游 IdP，下游 token 由目標平台簽發 | 下游 API 必須驗目標 issuer；不是繼續驗原 Keycloak token |
| 企業 SaaS | Keycloak 作 IdP，SaaS 作 SAML SP 或 OIDC RP | 簽章、metadata、NameID／subject、角色、付費 SSO 限制與登出 |

以應用→Keycloak→企業 IdP 為例，企業 IdP 的 token 不會自動變成 Keycloak 的 API token；Keycloak 會發出自己 realm 的 token。不要讓 Keycloak 和上游互相設定對方為唯一登入來源，形成循環與共同鎖死。

## 佈建與停權

SCIM Server 接收變更，SCIM Client／provisioner 發出變更；選型與部署都要註明方向。例如 HR／Entra 的佈建器 → Keycloak SCIM API，與 Keycloak → SaaS 的 outbound provisioning 是兩件事。首次登入建帳（JIT）不能保證來源停用者已在下游停用。[SCIM 協定](https://www.rfc-editor.org/rfc/rfc7644)。

Keycloak 26.8.0 文件將 `scim-api:v1` 列為正式支援且預設啟用；較舊版需查自己的功能狀態。這只證明其提供 SCIM API，不代表任意 SaaS 都能自動 outbound 同步。[Features](https://www.keycloak.org/server/features)、[版本變更](https://www.keycloak.org/docs/latest/upgrading/index.html)。

佈建實驗要驗證建立、改名、更新、移除群組、`active=false`、重送、分頁、錯誤重試與來源衝突。對 26.8.0 SCIM 的 Bulk、ETag、排序、密碼變更與組織群組限制，依 [SCIM 管理章節](https://www.keycloak.org/docs/latest/server_admin/index.html)及實際 `ServiceProviderConfig` 判斷，不能只測建立一個帳號。

## 多租戶與業務授權

Realm 可區分不同身分域，Client 表示應用信任關係，Organization 表示組織模型；都不會替 API 自動限制「只能讀本公司訂單」。建議以伺服器確認的組織會員關係決定 tenant，讓資料查詢與操作同時帶入租戶、角色及資源所有權條件，拒絕信任前端傳來的 `tenant_id`。

小型環境可在一個 Realm 用 Organizations／Groups 與應用 membership 模型，但要驗證隔離；有獨立安全政策、管理邊界或身份域需求時才評估分 Realm。正式與測試環境優先分 instance／DB，避免測試設定影響正式 token。

粗粒度應用角色可放 Keycloak；單筆資源共享、關係授權或高變動政策可在業務層或專用授權服務執行。Casbin、OPA、OpenFGA／Keto 是補足特定授權模型的候選，不直接取代身分登入。
