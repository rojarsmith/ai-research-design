# nginx 維護頁與備援設定範例

[返回主研究](../README.zh-TW.md) · [操作與驗收](../research/02-implementation-and-validation.zh-TW.md)

| 檔案 | 放在哪裡 | 用途 |
| --- | --- | --- |
| [nginx-a-local-maintenance.conf](nginx-a-local-maintenance.conf) | A | 應用失敗或維護旗標存在時，回本機 HTML／JSON 503 |
| [nginx-b-maintenance-only.conf](nginx-b-maintenance-only.conf) | B | 一般網址回維護 503，專用 `/readyz` 回 200 |
| [nginx-external-primary-backup.conf](nginx-external-primary-backup.conf) | A 以外的入口 C | A 為主要 HTTPS 上游，B 為完整應用備援；失敗時可回 C 的維護頁 |
| [maintenance.html](maintenance.html) | 範例的 `/srv/maintenance/` | 不載入外部 CSS、字型或 JavaScript 的頁面 |
| [maintenance.json](maintenance.json) | 範例的 `/srv/maintenance/` | API 維護訊息 |

這些是研究用模板，未在本機 nginx 或 VPS 上執行；目前工作環境未提供 nginx。全部 listener 刻意綁 `127.0.0.1:8080`，不會直接成為正式對外 HTTPS 設定。各模板要分別放在對應主機，不可原封不動一起放在同一 listener。

使用前依序完成：

1. 修改 `example.com`、`status.example.net`、來源 IP、應用 port、CA bundle 路徑；兩個 reserved IP 是文件示例，不是可連線的主機。
2. 將 HTML 與 JSON 放到設定的 root，確保 nginx 使用者可讀；正式頁面移除「網址為範例」說明，並改成合適的故障或計畫維護文字。
3. 使用 Linux nginx 的標準 `http` include 結構，確認載入 MIME types；各設定並非完整 `nginx.conf`。
4. 整合正式 `listen 443 ssl`、憑證與 port 80 的 HTTPS 轉向。若再放在可信外部 TLS 入口後面，正確設定 real IP 與轉送協定，不能直接信任任何訪客傳入的 Forwarded 標頭。
5. 由遠端 E 連接 A/B 時，改成可到達的來源 listener，配置防火牆；B 對外代理到 A 應使用 HTTPS 或受保護的私網，不應在公網裸送登入 Cookie。
6. 替 A 實作真實 `/readyz`，並依實際 API 前綴、webhook 路徑、CORS、FastCGI、WebSocket 或 SSE 需求調整。精確 `/api` 和 `/api/` 子路徑皆有 JSON 錯誤處理。
7. 執行 `nginx -t`，再依[驗收表](../research/02-implementation-and-validation.zh-TW.md)測試。模板不代表已通過實際故障切換。

範例只攔截 502、503、504；500 是否也轉成維護頁要按應用語意決定。其他狀態如 401、403、404、422 原則上保留。nginx 本身無法修復已送到客戶端一半的回應；API 範例停止同一請求的上游重試，避免交易被入口重播。

`proxy_read_timeout` 是兩次讀取間的逾時，並非整個 HTTP 請求的總時間。外部主備範例的 5 秒 next-upstream window 也不是保證完整回應在 5 秒內完成；要依正常延遲與故障種類量測。多個 nginx worker 共用範例的 upstream zone，但仍是被動失敗判定，不具備主動 `/readyz` 探測、成功次數門檻或 60 秒穩定觀察的自動控制。

在完整 API 備援情境，`proxy_next_upstream off` 只禁止重播當前請求，不禁止後續新請求選到 B；也不提供完整的 HTTP 失敗健康偵測策略。若 API 是主要流量、必須以 readiness 自動退出及回切，應採主動健康檢查入口。非 API 的寫入端點也要採相同保護；冪等、重試和查詢交易結果必須由應用程式定義。
