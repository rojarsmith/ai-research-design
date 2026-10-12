# iThome Keycloak 系列索引與設定更新

[回主報告](../README.zh-TW.md)。整理日期：2026-10-12。

來源為 lagagain 的[用 Keycloak 學習身份驗證與授權](https://ithelp.ithome.com.tw/users/20112470/ironman/4324)。系列頁共有 **41 篇**，主要技術文章發表於 2021 年，另含完賽感想、雜談、預告與 2022-05-18 的[系列目錄](https://ithelp.ithome.com.tw/articles/10285231)。文章標題 Day 編號與系列篇次不同，例如 Day00 是第 1 篇；不能把 41 篇解讀成 41 篇完整部署教學。

本文保留來源、篇次、主題閱讀指引與必要更新，沒有複製全文或圖片。五頁目錄均已核對；Day01、02、06、18、28、31、34 與作者系列目錄另讀取正文。其他文章列為索引，以下的操作指南另以標準及官方文件補足，不宣稱逐篇正文都完成重驗。

## 完整 41 篇索引

表內保留文章主要題名；入門篇、概念篇等分類可見原頁。閱讀用途是本指南的整理。

| 系列篇次 | 文章 | 閱讀用途 |
| --- | --- | --- |
| 1 | [Day00 開始之前](https://ithelp.ithome.com.tw/articles/10264887) | 系列範圍 |
| 2 | [Day01 Quick Start 1](https://ithelp.ithome.com.tw/articles/10265784) | Docker、Realm、Client、測試帳號；正文已核對 |
| 3 | [Day02 Quick Start 2](https://ithelp.ithome.com.tw/articles/10266496) | Angular 登入；正文已核對，流程需更新 |
| 4 | [Day03 淺談身份驗證與授權 1](https://ithelp.ithome.com.tw/articles/10267368) | 基礎名詞索引 |
| 5 | [Day04 淺談身份驗證與授權 2](https://ithelp.ithome.com.tw/articles/10267372) | 基礎名詞索引 |
| 6 | [Day05 什麼是 Keycloak](https://ithelp.ithome.com.tw/articles/10269082) | 產品概念索引 |
| 7 | [Day06 Keycloak 的替代品](https://ithelp.ithome.com.tw/articles/10269542) | 候選工具；正文已核對 |
| 8 | [Day07 什麼是 OAuth](https://ithelp.ithome.com.tw/articles/10270271) | 授權概念索引 |
| 9 | [Day08 OAuth 2.0 Playground](https://ithelp.ithome.com.tw/articles/10270968) | 流程觀察工具索引 |
| 10 | [Day09 再談身份驗證與授權](https://ithelp.ithome.com.tw/articles/10271674) | 概念複習索引 |
| 11 | [Day10 深入 OAuth 2.0](https://ithelp.ithome.com.tw/articles/10272336) | 委派存取索引 |
| 12 | [Day11 OAuth 2.0 flows](https://ithelp.ithome.com.tw/articles/10272994) | 流程總覽索引 |
| 13 | [Day12 OAuth flows 上路前注意事項](https://ithelp.ithome.com.tw/articles/10273706) | 實驗準備索引 |
| 14 | [Day13 Password Grant Legacy](https://ithelp.ithome.com.tw/articles/10274346) | 舊流程歷史，勿用於新整合 |
| 15 | [Day14 Implicit Legacy](https://ithelp.ithome.com.tw/articles/10275033) | 舊流程歷史，勿當新 SPA 預設 |
| 16 | [Day15 Authorization Code](https://ithelp.ithome.com.tw/articles/10275643) | Code 流程索引 |
| 17 | [Day16 Refresh Token](https://ithelp.ithome.com.tw/articles/10276199) | 更新 token 索引 |
| 18 | [Day17 Client Credentials](https://ithelp.ithome.com.tw/articles/10276655) | M2M 索引 |
| 19 | [Day18 PKCE](https://ithelp.ithome.com.tw/articles/10277215) | Code 流程綁定；正文已核對 |
| 20 | [Day19 Device Code 1](https://ithelp.ithome.com.tw/articles/10277710) | Device Flow 索引 |
| 21 | [Day20 Device Code 2](https://ithelp.ithome.com.tw/articles/10278196) | Device Flow 實驗索引 |
| 22 | [Day21 在 Flow 旅途外的風景](https://ithelp.ithome.com.tw/articles/10278658) | 流程延伸索引 |
| 23 | [Day22 Keycloak 基本概念前導](https://ithelp.ithome.com.tw/articles/10279129) | 管理模型索引 |
| 24 | [Day23 Realm](https://ithelp.ithome.com.tw/articles/10279558) | 身分域索引 |
| 25 | [Day24 Client](https://ithelp.ithome.com.tw/articles/10280070) | 應用登記索引 |
| 26 | [Day25 Scopes and Claims](https://ithelp.ithome.com.tw/articles/10280427) | 權限與 token 內容索引 |
| 27 | [Day26 User and Group](https://ithelp.ithome.com.tw/articles/10280744) | 帳號與群組索引 |
| 28 | [Day27 User Claim Profile](https://ithelp.ithome.com.tw/articles/10281089) | 身分屬性索引 |
| 29 | [Day28 Role](https://ithelp.ithome.com.tw/articles/10281429) | Realm／Client 角色、群組繼承；正文已核對 |
| 30 | [完賽感想 30 天的結束不是完結](https://ithelp.ithome.com.tw/articles/10281725) | 作者心得，非營運教材 |
| 31 | [Day29 JWT 權杖格式介紹 1](https://ithelp.ithome.com.tw/articles/10281431) | JWT 格式索引 |
| 32 | [Day30 OpenID Connect and Social Login 1](https://ithelp.ithome.com.tw/articles/10281985) | 社群登入索引 |
| 33 | [Day31 OpenID Connect and Social Login 2](https://ithelp.ithome.com.tw/articles/10281433) | 跨 Realm broker、帳號連結；正文已核對 |
| 34 | [雜談 鐵人賽觀察 1](https://ithelp.ithome.com.tw/articles/10281434) | 非技術操作 |
| 35 | [Day32 Device Code 3](https://ithelp.ithome.com.tw/articles/10281435) | Device Flow 應用索引 |
| 36 | [Day33 Device Code 4 預告](https://ithelp.ithome.com.tw/articles/10281443) | 部分內容移除，不能當完整實作 |
| 37 | [Day34 使用 iFrame 實現 Dialog 彈跳登入 預告](https://ithelp.ithome.com.tw/articles/10281436) | 登入 UI 構想；正文已核對 |
| 38 | [雜談 2](https://ithelp.ithome.com.tw/articles/10281440) | 非技術操作 |
| 39 | [預告 遺珠之憾](https://ithelp.ithome.com.tw/articles/10281437) | 後續規劃 |
| 40 | [雜談 3 有意思的系列](https://ithelp.ithome.com.tw/articles/10281438) | 延伸閱讀 |
| 41 | [系列目錄](https://ithelp.ithome.com.tw/articles/10285231) | 作者網站入口與後記；正文已核對 |

## 可用的閱讀路線

| 目的 | 原系列順序 | 接著讀本地指南 |
| --- | --- | --- |
| 理解第一次登入 | Day01 → 02 → 03 → 04 | [整合設定](02-integration.zh-TW.md)與[實驗環境](../examples/keycloak-lab/README.zh-TW.md) |
| 寫 Web／SPA | Day11 → 15 → 18 → 16 | Code + PKCE、BFF、refresh 與登出驗收 |
| 接 API／排程 | Day17 → 25 → 28 → 29 | Audience、JWT 驗證、服務帳號與業務授權 |
| 管理帳號與權限 | Day22 → 23 → 24 → 26 → 27 → 28 | [營運](05-keycloak-operations.zh-TW.md)中的停權與權限覆核 |
| 接企業或社群 IdP | Day30 → 31 | 帳號連結、broker、佈建方向與來源停權 |
| CLI／設備登入 | Day19 → 20 → 32 | 裝置碼防釣魚、輪詢、拒絕與超時驗收 |
| 選替代品 | Day06 | [2026 方案比較](01-iam-comparison.zh-TW.md) |

## 已核對文章的重點

- **Day01／02**：先在 Keycloak 登記 Realm、Client 和測試帳號，再由 Angular 的 OIDC library 完成登入與登出。這個教學結構仍可沿用，程式與設定需更新。
- **Day06**：把雲端身分服務、專用 IdP 與授權工具列為候選；這些工具的責任不同。本指南將 CIAM、員工 IAM 和授權組件分開比較。
- **Day18**：示範 `code_verifier`／`code_challenge` 如何把換碼端綁到發起流程的一方。實作優先用維護中的 library；不要把 Client Credentials Grant 與 Code Flow 的 client authentication 混為一談。
- **Day28**：示範 Realm Role、Client Role 與 Group 繼承。取消使用者直接角色後，仍要檢查群組及複合角色帶來的有效權限。
- **Day31**：另一個 Realm 可以作上游 IdP，首次登入可連到既有帳號；原例要求證明對原帳號的所有權。正式整合須保留等價的驗證，避免僅憑相同 email 合併。
- **Day34**：可見正文是 iframe 登入的預告與構想，不是完整的生產範例。登入畫面改動應遵守瀏覽器安全限制。

## 舊設定與現在的做法

| 原教材情境 | 現在應如何使用 | 核對依據 |
| --- | --- | --- |
| Day01 使用 Keycloak 15.0.2 與 `KEYCLOAK_USER/PASSWORD` | 舊命令只供歷史理解；現代映像使用版本相符的 `KC_*` 設定與 bootstrap 機制 | [Container guide](https://www.keycloak.org/server/containers) |
| Day02、31 的 `/auth/realms/...` | 現代預設通常是 `/realms/...`；若原部署保留 `/auth`，不要直接刪除，先讀 actual discovery | [OIDC endpoints](https://www.keycloak.org/securing-apps/oidc-layers)、[Hostname](https://www.keycloak.org/server/hostname) |
| Day02 啟用 Implicit，`response_type=id_token` | 新 SPA 改 Code + PKCE S256；不把教材快開始設定原封用於正式站 | [OAuth Security BCP](https://www.rfc-editor.org/rfc/rfc9700) |
| Day13 Password Grant | 新整合不讓應用收取使用者的 IdP 密碼；改適合該應用的重新導向流程 | [RFC 9700](https://www.rfc-editor.org/rfc/rfc9700) |
| Day02 的 callback `/*` 與 localStorage | 登記精確 callback；縮小 token 曝露面，SPA 用記憶體或改 BFF；仍需防 XSS | [RFC 9700](https://www.rfc-editor.org/rfc/rfc9700)、[JS adapter](https://www.keycloak.org/securing-apps/javascript-adapter) |
| Day02 的 `oidc-client` 套件與舊 UI | 按目前維護中的 OIDC library 或 framework 文件實作；不因類名相似就直接替換依賴 | [官方整合指南](https://www.keycloak.org/guides) |
| Day18 的 PKCE 說明 | PKCE 是 Code Flow 的強化，不是服務帳號 grant；每次產生新 verifier，使用 S256，仍驗證流程的 state／nonce | [RFC 9700](https://www.rfc-editor.org/rfc/rfc9700) |
| Day28 的角色配置 | API 明確讀取目標 Client roles，並加入租戶與資源檢查 | [OWASP REST Security](https://cheatsheetseries.owasp.org/cheatsheets/REST_Security_Cheat_Sheet.html) |
| Day31 跨 IdP 合併 | 以來源 subject 和受驗證的帳號連結政策處理；不要自動信任任意來源 email | [管理指南](https://www.keycloak.org/docs/latest/server_admin/index.html) |
| Day34 iframe 登入構想 | 優先標準頁面跳轉；不要為顯示登入框全面放寬 CSP／frame 限制；silent SSO 要有瀏覽器限制的備援 | [JS adapter 的瀏覽器限制](https://www.keycloak.org/securing-apps/javascript-adapter) |

## 營運需補上的內容

這個系列可用於概念學習；現有服務的 DB 備份、還原演練、正式 TLS／proxy、監控、叢集、升級與事件處理，另外依[部署指南](04-keycloak-deployment.zh-TW.md)、[營運手冊](05-keycloak-operations.zh-TW.md)及[驗收清單](06-acceptance.zh-TW.md)執行。作者 2022 年後記也提到後續接觸 HA、反向代理、WebAuthn 等議題，不能據此推定這些操作已在舊系列完整實作。
