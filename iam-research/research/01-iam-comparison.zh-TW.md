# 主流 IAM 的優劣與整合方式

[回主報告](../README.zh-TW.md)。查核日期：2026-10-12。

這裡選取十一組常見方案，涵蓋自架 IdP、員工 IAM、CIAM 與組件式架構；不是依市占率排序。功能是官方記載，優劣與適用情境是依架構責任的分析，沒有進行跨產品效能或安全性評分。

## 自架與可自行控制部署的方案

| 方案 | 優點 | 限制與營運負擔 | 整合方向與適用情境 |
| --- | --- | --- | --- |
| **Keycloak** | OIDC、SAML、身分代理、目錄聯邦及可自訂登入流程；已有部署時可累積既有 Client 與權限設定 | 自行負責 JVM、DB、叢集、修補、主題與 SPI 相容性；不等於完整員工治理／裝置管理平台 | 新 Web/API 用 OIDC，舊企業應用用 SAML；AD/LDAP 用 User Federation；Entra/Okta 作上游 IdP。適合有自架能力的多應用環境。[管理文件](https://www.keycloak.org/docs/latest/server_admin/index.html) |
| **authentik** | Provider 涵蓋 OIDC、SAML、LDAP、Proxy、RADIUS，對異質內部應用有多種接入選擇 | Outpost、代理與各協定形成額外維護面；Enterprise 功能需核對版本與付費方案 | 有 OIDC/SAML 的應用直接串接；無原生 SSO 的應用評估 Proxy Provider。代理認證後仍需處理應用資料權限。[Providers](https://docs.goauthentik.io/add-secure-apps/providers/)、[方案](https://goauthentik.io/pricing/) |
| **ZITADEL** | 組織、專案與委派管理模型適合 B2B；提供 Cloud 與 self-hosted 路線 | 自架仍要維護 DB、登入服務與密鑰；組織模型與 Keycloak Realm 不一對一，遷移需重新映射 | OIDC／SAML 接應用，企業客戶以組織和專案授權區分；自架與 Cloud 逐項比功能及條款。[組織](https://zitadel.com/docs/guides/manage/console/organizations-overview)、[自架](https://zitadel.com/docs/self-hosting/deploy/overview) |
| **Ory** | Kratos、Hydra、Keto、Oathkeeper 各負責不同領域，可組成符合產品需求的身分與授權架構 | 多個服務、資料庫、登入／同意畫面及服務間介面需整合；Hydra 單獨不構成完整會員系統 | Kratos 處理身分，Hydra 處理 OAuth/OIDC，Keto 處理細粒度授權，Oathkeeper 處理入口存取；適合願意投入產品工程的團隊。[OSS 組件](https://www.ory.com/docs/oss/getting-started)、[Hydra](https://www.ory.com/docs/network/hydra) |
| **WSO2 Identity Server** | 文件涵蓋 OIDC、SAML、企業聯邦、佈建與條件驗證；可整合複雜企業需求 | 設定、擴充、更新及支援安排需專門評估；不因功能表長就代表小型環境更合適 | 適合既有 WSO2／企業整合環境；用標準協定接應用，佈建流程需另做故障與重試驗收。[官方文件](https://is.docs.wso2.com/en/latest/) |
| **PingFederate** | 可銜接 OIDC、OAuth、SAML、WS-Federation，適合保留既有異質企業身分系統 | 商業授權、部署、整合套件與專業維護成本需報價；PingFederate、PingOne、PingDirectory 等不能視為同一個產品 | 既有企業聯邦中作 IdP／SP／授權伺服器；與 Keycloak 透過 OIDC/SAML 接一個明確方向。[SSO 概念](https://docs.pingidentity.com/pingfederate/13.1/introduction_to_pingfederate/pf_sso_integr_concept.html)、[產品範圍](https://www.pingidentity.com/en/product/pingfederate.html) |

## 託管身分服務

| 方案 | 優點 | 限制與費用風險 | 整合方向與適用情境 |
| --- | --- | --- | --- |
| **Auth0** | 託管登入、SDK／框架範例與企業連線，適合產品團隊快速建立 CIAM | 功能和額度依 B2C/B2B、MAU、企業連線、組織、MFA、M2M 與支援方案而變；匯出帳號不代表可完整搬走登入流程 | 應用連 Auth0；Keycloak 可作 OIDC 或 SAML enterprise connection 的上游。轉移 issuer、claims 與帳號連結需測試。[企業連線](https://auth0.com/docs/authenticate/identity-providers/enterprise-identity-providers)、[方案](https://auth0.com/pricing) |
| **Okta Workforce Identity** | 可集中企業目錄與外部 IdP 連線；適合員工跨應用登入與管理 | 員工方案、Lifecycle、治理、API 授權、支援與套件需逐項核價；不要把 Okta org token 視為任何自家 API 都能接受 | 員工 SaaS 以 OIDC/SAML 接入，生命週期另接 provisioning；Keycloak 可作下游 broker 或上游 IdP。[IdP](https://developer.okta.com/docs/concepts/identity-providers/)、[價格與套件](https://www.okta.com/pricing/) |
| **Microsoft Entra ID／External ID** | 員工 tenant 適合 Microsoft 365 環境；客戶登入可另建 external tenant | Workforce 與 External tenant 的功能不能混用；條件式存取、治理及授權方案需分開核對 | 員工以 Entra 為來源，Keycloak broker 承接自家應用；客戶方案評估 External ID。新客戶不能再按舊文章採購 Azure AD B2C。[Tenant 分工](https://learn.microsoft.com/en-us/entra/external-id/tenant-configurations)、[功能比較](https://learn.microsoft.com/entra/external-id/customers/overview-solutions-customers) |
| **Amazon Cognito** | User Pool 提供應用登入、OIDC IdP、外部 SAML/OIDC 與 M2M；適合 AWS 產品環境 | User Pool 與 Identity Pool 責任不同；Managed Login、passkey、威脅保護與費率依方案；AWS 生態整合形成遷移成本 | Keycloak → Cognito User Pool 可作外部 IdP；Identity Pool 另負責 AWS 臨時憑證。API 需依 Cognito token 規則驗證。[User Pool](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools.html)、[價格](https://aws.amazon.com/cognito/pricing/) |
| **Firebase Authentication／Google Identity Platform** | Web、行動 SDK 和 Firebase 服務整合方便；Identity Platform 補上企業 IdP、多租戶等能力 | 基本 Firebase Authentication 與升級版功能不同；使用 Firebase token／SDK 的應用需要專門遷移，不能只替換 issuer | Keycloak 作上游 OIDC/SAML 須用具備該能力的 Identity Platform 路線；下游仍得到 Google/Firebase 身分 token。[Firebase](https://firebase.google.com/docs/auth)、[兩者差異](https://docs.cloud.google.com/identity-platform/docs/product-comparison) |

## 與現有 Keycloak 的關係

| 需求 | 優先比較 | 如何利用既有部署 |
| --- | --- | --- |
| 自架多個 Web/API，需求可由標準登入完成 | Keycloak、authentik | 先統一 OIDC Client 與營運基線；避免為每個應用再開一套會員密碼 |
| 內部應用多數缺乏原生 SSO | authentik、OIDC 代理搭配 Keycloak | 先盤點 Proxy 覆蓋範圍；不因入口有 SSO 就移除 API 的權限檢查 |
| 員工大量使用 Microsoft 365 | Entra、Okta | 員工帳號留在企業目錄，Keycloak 接企業 IdP；把離職停權獨立驗收 |
| 產品团队不願承擔 IAM 值班 | Auth0、Cognito、Identity Platform、ZITADEL Cloud | 以一個測試應用和一個 Realm／客群做遷移 POC；先估 MAU 與 M2M 成本 |
| 多個企業客戶自行管理 SSO 與人員 | ZITADEL、Auth0、Keycloak Organizations、Entra External ID | 比較委派、組織歸屬、佈建、租戶隔離與每客戶成本；不要只比登入畫面 |
| 自訂會員產品、授權模型高度特殊 | Ory、Keycloak 加應用授權層 | 先釐清哪些政策在 IdP、哪些必須在 API 與資料層 |
| 大型既有聯邦與企業整合 | PingFederate、WSO2、Keycloak | 把既有協定、支援責任與遷移停機時間列為必要條件 |

以上是條件式篩選，不是全局排名。這個目錄未涵蓋所有市場產品；JumpCloud、Gluu/Jans、Curity、Duende IdentityServer、CAS 等是指定教材中的延伸候選，可在具體需求出現時深入。

## 成本與授權怎麼比

每個候選填同一張試算：`年度總成本 = 授權／訂閱 + 主機與DB + 備份及監控 + 郵件／SMS + 維運工時 + 支援 + 遷移攤提`。MAU、人數、M2M 請求與企業連線是不同計價單位，不能把「免費用戶額度」套到所有流量。

例如只為示範計算，假設自架每月基礎設施與備份 US$80、維護 8 小時、每小時 US$30，年度為 `(80 + 8 × 30) × 12 = US$3,840`，尚未包含事故、遷移與稅。這不是主機報價或 Keycloak 需求估算；只有用同樣工作量算託管方案，數字才可比較。

Keycloak repository 標示 Apache 2.0；ZITADEL 目前 repository 標示 AGPL-3.0 並有目錄例外，不能沿用舊版本的授權印象。authentik 的社群與 Enterprise 範圍、Ory 各組件與商業服務、WSO2 的發行及更新支援，均應以採用的版本及合約查核。免費自架與商業支援是不同條件。[Keycloak repo](https://github.com/keycloak/keycloak)、[ZITADEL 授權](https://github.com/zitadel/zitadel)、[authentik pricing](https://goauthentik.io/pricing/)、[ZITADEL pricing](https://zitadel.com/pricing/detail)。

## 公平的比較實驗

在相同需求下評估兩至三個候選：兩個應用 SSO、一個企業 IdP、MFA、停權、角色變更、租戶越權、日誌匯出、金鑰輪替與遷移退出。記錄成功條件、費用方案、操作步驟、停機與回復時間；性能比較必須固定密碼雜湊設定、DB、硬體與請求組成。未量測之前，不寫哪個產品「最快」或「最安全」。
