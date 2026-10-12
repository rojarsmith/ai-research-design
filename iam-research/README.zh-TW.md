[English overview](README.md) | **繁體中文**

# IAM 方案比較與 Keycloak 架設營運指南

研究日期：2026-10-12（Asia/Taipei）。本指南比較常見 IAM 方案、應用整合方式，以及現有 Keycloak 的架設、維護、備份與故障處理。你目前已架設 Keycloak，表示使用最新版，但忘了當初的架設方式；因此優先工作是找回部署資訊並完成還原演練，接著改善應用整合與維運。

**目前建議：先把現有 Keycloak 變成可理解、可還原、可升級的服務。** 若需求主要是 Microsoft 365 員工帳號、跨 SaaS 帳號生命週期、或希望把值班與修補交由服務商負責，再用相同驗收情境比較 Entra、Okta、Auth0 等方案。已經使用 Keycloak 是遷移成本的考量，不代表它適合所有情境。

## 先從現有部署開始

1. 填寫[現有環境盤點](templates/current-deployment.zh-TW.md)，找出主機、啟動方式、實際版號、資料庫、DNS、TLS 與備份位置。只填描述與秘密的保管位置，不要填密碼。
2. 依[架設指南](research/04-keycloak-deployment.zh-TW.md)完成只讀盤點，先確認資料庫與還原方式，再安排任何設定變更。
3. 用[營運手冊](research/05-keycloak-operations.zh-TW.md)建立監控、管理員復原與升級流程。
4. 每接一個應用，都用[整合指南](research/02-integration.zh-TW.md)設定獨立 Client，並執行[驗收清單](research/06-acceptance.zh-TW.md)。

## 文件入口

| 文件 | 可解決的問題 |
| --- | --- |
| [主流 IAM 比較](research/01-iam-comparison.zh-TW.md) | 哪些方案適合自架、員工、客戶、B2B；各自的功能、限制、成本與整合方向 |
| [應用與企業整合](research/02-integration.zh-TW.md) | SPA、BFF、後端 API、手機／桌面、M2M、SAML、LDAP、SCIM 與租戶授權 |
| [指定 iThome 系列彙整](research/03-ithome-series.zh-TW.md) | 41 篇完整索引、主題閱讀順序，以及舊設定的現代替代做法 |
| [Keycloak 部署](research/04-keycloak-deployment.zh-TW.md) | 忘記部署方式時如何盤點；實驗環境如何建立；正式環境如何規劃 |
| [Keycloak 營運](research/05-keycloak-operations.zh-TW.md) | 告警、備份還原、升級、離職停權、金鑰輪替、事故排查 |
| [上線與變更驗收](research/06-acceptance.zh-TW.md) | 除了登入成功，還要證明哪些拒絕、隔離、復原行為 |
| [來源與查核紀錄](research/07-sources.zh-TW.md) | 官方文件、標準與教材的適用範圍及版本 |
| [本地 Keycloak 實驗環境](examples/keycloak-lab/README.zh-TW.md) | 在獨立資料庫試驗 Realm、Client、Code + PKCE 與健康檢查 |

## IAM 的責任分工

| 範圍 | 主要工作 | 選型重點 |
| --- | --- | --- |
| 員工 IAM | 員工、裝置、企業 SaaS、到職與離職 | 既有目錄、MFA、裝置政策、佈建、管理權限 |
| 客戶 IAM／CIAM | 註冊、登入、社群登入、企業客戶 SSO | 登入體驗、B2B 組織、資料地域、流量與費用 |
| 工作負載身分 | 服務對服務、批次工作、雲端資源 | 憑證保管、短效憑證、可追溯的服務身分 |
| 應用授權 | 可以讀哪筆資料、可執行哪些操作 | API 與資料層的角色、租戶、所有權與關係規則 |

OAuth 2.0 處理委派存取，OIDC 在其上提供登入身分；SCIM 處理帳號與群組的佈建。登入成功不代表取得每筆業務資料的權限。AWS IAM、Google Cloud IAM 與 Azure RBAC 是雲端資源權限系統，不能直接當成網站會員登入服務的替代品。[OIDC 標準](https://openid.net/specs/openid-connect-core-1_0.html)、[SCIM 協定](https://www.rfc-editor.org/rfc/rfc7644)。

## 版本與資料使用方式

查核時官方下載頁與升級指南顯示 Keycloak **26.8.0**；本文以這個版本的文件作為參考。你實際安裝的版號仍待盤點，「最新版」必須以服務上的版號或映像 digest 確認。[官方下載](https://www.keycloak.org/downloads)、[升級指南](https://www.keycloak.org/docs/latest/upgrading/index.html)。

指定系列是 lagagain 的 2021 年教材，2022 年另有系列目錄。範例使用 Keycloak 15.0.2，適合理解流程，但舊環境變數、`/auth` 路徑、Implicit Flow 與前端 token 儲存方式需重新評估；詳細對照見[教材彙整](research/03-ithome-series.zh-TW.md)。

比較中的功能依官方文件列出，適用性與取捨是工程判斷；沒有以廠商宣傳或其他公司的利益作為排名依據。這次研究尚未連線到你的 Keycloak，實驗檔也不會自動更動現有服務。實際 HA、效能與費用需以你的環境和工作量驗收。
