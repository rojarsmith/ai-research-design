# IAM 來源與查核紀錄

[回主報告](../README.zh-TW.md)。查核日期：2026-10-12（Asia/Taipei）。

功能與設定以各產品的官方文件核對，安全流程另參照 IETF、OpenID Foundation 與 OWASP。廠商文件可證明其記載的功能與方案，不能單憑該來源比較誰更安全、效能更高或維護成本更低；本指南的適用情境與維運安排屬工程分析。

## Keycloak

| 來源 | 用途與查核結果 |
| --- | --- |
| [Downloads](https://www.keycloak.org/downloads) | 可見版本 26.8.0；Node.js adapter 標為 deprecated。未據此判定你的安裝版號 |
| [Guides](https://www.keycloak.org/guides) | 官方部署、觀測、應用與 HA 的入口 |
| [Containers](https://www.keycloak.org/server/containers) | build／optimized、bootstrap、development mode、容器限制 |
| [Database](https://www.keycloak.org/server/db) | 支援 DB 清單；查核時 PostgreSQL 17.x 在支援範圍 |
| [Reverse proxy](https://www.keycloak.org/server/reverseproxy) | TLS 模式、header 信任、backend 網路與 management port |
| [Hostname](https://www.keycloak.org/server/hostname) | issuer／hostname／admin hostname 與安全邊界 |
| [Distributed caches](https://www.keycloak.org/server/caching) | 叢集、快取與節點發現 |
| [Features](https://www.keycloak.org/server/features) | 查核時 SCIM 正式支援、預設啟用；preview 與 deprecated 要區分 |
| [OIDC endpoints](https://www.keycloak.org/securing-apps/oidc-layers) | discovery、auth、token、JWKS、logout 的用途與路徑 |
| [JavaScript adapter](https://www.keycloak.org/securing-apps/javascript-adapter) | token 儲存、SPA 與瀏覽器限制 |
| [Server administration](https://www.keycloak.org/docs/latest/server_admin/index.html) | 角色、身分代理、帳號與事件；SCIM 方向及能力限制 |
| [Health](https://www.keycloak.org/observability/health) | Ready／Live／Started、9000、容器沒有 curl、DB check 的條件 |
| [Metrics](https://www.keycloak.org/observability/configuration-metrics) | 管理介面、OpenMetrics 與 histogram |
| [Import and export](https://www.keycloak.org/server/importExport) | Realm export 的一致性與資料覆蓋限制 |
| [Upgrading](https://www.keycloak.org/docs/latest/upgrading/index.html) | 26.8.0 文件與各版本 migration notes，SCIM 狀態變更 |
| [Update compatibility](https://www.keycloak.org/server/update-compatibility) | 依部署差異檢查 rolling 或 recreate；不保證任意版本組合相容 |
| [Repository](https://github.com/keycloak/keycloak) | Apache 2.0 與原始碼來源 |

`latest` 文件與下載頁會更新；部署要保存實際使用的版本／digest，重查相應版本文件，不把本次的 26.8.0 永久寫成最新版。

## 其他 IAM 方案

| 來源 | 用途 |
| --- | --- |
| [authentik Providers](https://docs.goauthentik.io/add-secure-apps/providers/) | OIDC、SAML、LDAP、Proxy 等接入種類 |
| [authentik Pricing](https://goauthentik.io/pricing/) | 社群與 Enterprise 方案範圍 |
| [ZITADEL Organizations](https://zitadel.com/docs/guides/manage/console/organizations-overview) | 組織、專案、隔離與委派 |
| [ZITADEL Self-hosting](https://zitadel.com/docs/self-hosting/deploy/overview) | 自架方式及 PostgreSQL 依賴 |
| [ZITADEL Repository](https://github.com/zitadel/zitadel) | 查核時主專案為 AGPL-3.0，部分目錄另有例外 |
| [ZITADEL Pricing](https://zitadel.com/pricing/detail) | Cloud／self-hosted／enterprise 方案與用量條件 |
| [Ory OSS](https://www.ory.com/docs/oss/getting-started) | 組件範圍與自行整合責任 |
| [Ory Hydra](https://www.ory.com/docs/network/hydra) | OAuth/OIDC 服務與 headless 模型；不是完整會員 UI |
| [Auth0 Enterprise IdPs](https://auth0.com/docs/authenticate/identity-providers/enterprise-identity-providers) | 企業 OIDC/SAML 等連線 |
| [Auth0 Pricing](https://auth0.com/pricing) | B2B/B2C、MAU、功能和加購；未將畫面預設價格當全面報價 |
| [Okta IdPs](https://developer.okta.com/docs/concepts/identity-providers/) | broker、外部 OIDC/SAML、JIT 與帳號連結 |
| [Okta Pricing](https://www.okta.com/pricing/) | 員工產品的套件與費用來源 |
| [Entra tenant configurations](https://learn.microsoft.com/en-us/entra/external-id/tenant-configurations) | Workforce／External 的分工；2025-05-01 起 Azure AD B2C 不供新客戶購買 |
| [Entra features](https://learn.microsoft.com/entra/external-id/customers/overview-solutions-customers) | 依 tenant 區分支援能力 |
| [Cognito User Pools](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools.html) | 應用登入、外部 IdP、M2M 與 Identity Pool 的不同責任 |
| [Cognito Pricing](https://aws.amazon.com/cognito/pricing/) | 用量與方案費率，M2M 應另計 |
| [Firebase Auth](https://firebase.google.com/docs/auth) | Web／行動 SDK 與認證功能 |
| [Identity Platform comparison](https://docs.cloud.google.com/identity-platform/docs/product-comparison) | 基本 Firebase 與升級版的 OIDC/SAML、多租戶等差異 |
| [PingFederate SSO](https://docs.pingidentity.com/pingfederate/13.1/introduction_to_pingfederate/pf_sso_integr_concept.html) | 企業身分聯邦概念 |
| [PingFederate product](https://www.pingidentity.com/en/product/pingfederate.html) | 產品及協定範圍；不當作獨立性能證據 |
| [WSO2 Identity Server](https://is.docs.wso2.com/en/latest/) | OIDC/SAML、條件認證、企業整合與 provisioning 文件 |

費用比較未鎖定使用量、區域、幣別、合約或 SLA，故不列不可比的「每月最低價」排名；採用前依[相同成本模型](01-iam-comparison.zh-TW.md)詢價。ZITADEL 的授權標示來自 repository，本文沒有推定你修改或部署後的具體法律義務。

## 標準與安全指引

| 來源 | 核對用途 |
| --- | --- |
| [RFC 9700 OAuth Security BCP](https://www.rfc-editor.org/rfc/rfc9700) | Code + PKCE、redirect、舊 grant 的安全指引 |
| [OIDC Core](https://openid.net/specs/openid-connect-core-1_0.html) | 認證、ID Token、subject／issuer 與 key rotation |
| [RFC 8252 Native Apps](https://www.rfc-editor.org/rfc/rfc8252) | 系統瀏覽器與 native app 流程 |
| [RFC 7644 SCIM](https://www.rfc-editor.org/rfc/rfc7644) | 使用者／群組生命週期協定與方向 |
| [OWASP REST Security](https://cheatsheetseries.owasp.org/cheatsheets/REST_Security_Cheat_Sheet.html) | API token 驗證與每次操作授權 |
| [OWASP JWT](https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_Cheat_Sheet.html) | JWT 風險、秘密與撤銷 |

## 指定 iThome 系列

完整來源及讀取範圍見[41 篇索引](03-ithome-series.zh-TW.md)。系列首頁、五頁索引及作者 2022 年目錄已核對，另讀七篇重要正文；索引與正文查核狀態分開記錄。搜尋服務起初無法擷取系列頁，後由瀏覽器正常載入公開頁面；沒有登入、修改網站或繞過挑戰。

Day01／02 的原設定是教材當時的範例，不以現在的標準倒推作者當時已寫過現代設定。本指南以原文說明與官方目前做法並列，讓讀者知道哪些概念可延用，哪些部署與安全條件需要更新。

## 現況與驗證限制

- 你表示使用最新版，尚無實際版號／digest、host、DB、proxy、備份或應用清單。
- 本次沒有存取管理主控台、使用你的憑證或更動現有服務。
- Compose／Realm 是獨立實驗範例，未在此 workspace 執行 Docker build、啟動或真實登入。
- 產品比較没有跨產品 benchmark、支援品質實測或 SLA 故障統計。
- Discovery 檢查工具僅測端點與公鑰結構；不驗證完整登入、MFA、JWT 驗簽、授權或 HA。

本地檔案驗證：Markdown 相對連結、41 篇唯一索引、JSON／YAML 語法及 loopback／獨立 DB 的範例條件已檢查；PowerShell 語法解析通過。Discovery 工具以模擬回應確認正常 metadata／JWKS、錯誤 issuer、跨 origin JWKS、意外私鑰及遠端 HTTP 的處理；這些模擬不代表真實服務端測試。

下一個實際營運步驟是完成[環境盤點](../templates/current-deployment.zh-TW.md)及隔離還原；不需要先遷移 IAM 才能做這兩件事。
