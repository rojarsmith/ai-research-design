# 本地 Keycloak 實驗環境

[回主報告](../../README.zh-TW.md) · [部署指南](../../research/04-keycloak-deployment.zh-TW.md)。範例日期：2026-10-12。

這個範例供你練習 Realm、Public Client、Code + PKCE、audience 和角色。它有新的 PostgreSQL volume 與 `iam-lab` Realm，不是現有服務的恢復或升級工具。HTTP 僅綁定本機；不可改成公網暴露後直接用於正式服務。

Keycloak 映像固定 26.8.0，PostgreSQL 固定 major 17；PG tag 的 patch 仍可能變動，實驗成功後應記錄實際 digest。此 workspace 沒有 Docker，尚未 build、啟動與登入測試；不要把檔案存在當成通過上線驗收。

## 開始實驗

需要有可用的 Docker Engine／Docker Desktop、Compose v2、可用的 18080／19000 連接埠，以及足夠記憶體。Keycloak 限制 2 GiB，另需為 PostgreSQL、Docker 與主機留空間。先確認沒有同名 `iam-research-lab` project；有同名且用途不明時，先辨識它，不覆用其資料庫。

在這個目錄執行：

```powershell
docker compose ls
Copy-Item .env.example .env
```

以編輯器在 `.env` 設定兩組獨立、長且隨機的實驗密碼，不使用正式 DB／管理員密碼。`.env` 已由上層 `.gitignore` 排除。環境變數對 Docker 管理者可見，這不是 production secret store；不要把包含秘密的 config／inspect 輸出提交 Git。

```powershell
docker compose config --quiet
docker compose up -d --build
docker compose ps
```

等待服務啟動，再在同一台電腦開啟 [本地管理入口](http://localhost:18080/admin/)。Bootstrap 帳號是 `lab-admin`，密碼為你在 `.env` 填的值；Realm 是 `iam-lab`。使用 hostname `localhost`，不要在應用裡換成 `127.0.0.1`，兩者的 issuer 不同。

本地 HTTP 單節點配置執行 production `start` 只是為練習 build／optimized 與外部 DB；它沒有 TLS、HA、正式管理隔離或可靠備份，`sslRequired=none` 也僅限此 loopback 實驗。

## 檢查端點

在目錄中以 PowerShell 執行：

```powershell
Invoke-RestMethod http://localhost:19000/health/ready
Invoke-WebRequest http://localhost:19000/metrics -UseBasicParsing
../../tools/Test-IamDiscovery.ps1 -Issuer http://localhost:18080/realms/iam-lab -AllowLoopbackHttp
```

正式服務使用 HTTPS issuer，不加 HTTP 例外。Discovery 工具只讀取公開 metadata／JWKS，不使用帳號、密碼或 token，不測登入與授權；若 metadata 指向不同 origin 會停止，需先確認拓撲，不關閉 TLS 檢查。

## Client 與角色實驗

附帶的 `lab-spa` 是 Public Client，啟用 Code、要求 PKCE S256、關閉 Implicit／Password／Service Accounts，callback 僅為 `http://localhost:5173/callback`，登出回到 `http://localhost:5173/`。`lab-api` 是角色與 audience 用的 API 登記，沒有互動登入。

1. 在 Console 檢查 `lab-spa` 的上述設定與 mapper，確認 API audience 為 `lab-api`。
2. 建立一個合成測試使用者、設定僅供實驗的密碼，不匯入真實帳號。
3. 給該使用者 `lab-api` 的 `reader` 角色；用自己的本地應用或維護中的 OIDC library 接 `http://localhost:18080/realms/iam-lab`。
4. 應用必須實作 callback handler、state／nonce／PKCE 與 logout；這個 Compose 不會啟動前端／API，也不會自行提供 callback 頁面。
5. 檢查 access token 的 `aud` 與目標 Client roles；用 API 驗證器測 reader 可讀、不能編輯，及錯誤 audience／issuer 被拒絕。
6. 測 logout／refresh 與角色移除，確認舊 token 的有效期邊界。

`--import-realm` 只用於新實驗 DB 初始化；已有同名 Realm 時不會套用 JSON 修改，不能當持續更新機制。若要改設定，在實驗 Console 修改並記錄差異，不以 override import 覆蓋現有資料。[Import/export](https://www.keycloak.org/server/importExport)。

## 停止與保留資料

```powershell
docker compose stop
```

停止保留 DB volume；再次啟動可使用 `docker compose up -d`。需要重新建實驗時，先核對 project 與 volume 的身份再決定如何清除，不把正式資料庫或不明 volume 當作實驗資料。

設定依據：[Keycloak containers](https://www.keycloak.org/server/containers)、[DB](https://www.keycloak.org/server/db)、[health](https://www.keycloak.org/observability/health)、[OIDC endpoints](https://www.keycloak.org/securing-apps/oidc-layers)。
