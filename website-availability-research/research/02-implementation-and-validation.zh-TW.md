# nginx 維護頁與 A B 主備切換的實作和驗收

[返回主研究](../README.zh-TW.md)。以下是 Linux nginx 與一般外部 DNS／HTTP 入口的部署流程。所有主機、網址與路徑都是待替換範例；須先在測試環境驗證，再套用正式主機。

## A 上的本地維護頁

使用[本地維護模板](../examples/nginx-a-local-maintenance.conf)，把 [HTML](../examples/maintenance.html) 與 [JSON](../examples/maintenance.json) 放在 A 的 `/srv/maintenance/`。模板的服務入口為 localhost 8080，上游應用為 localhost 8000；正式對外需整合 HTTPS server block。

邏輯是：正常請求代理到程式；程式無法連線、503 或逾時造成 502／503／504，回本機 503 頁。`/api` 與 `/api/` 子路徑走 JSON，`/readyz` 保留真實健康狀態。檔案存在判斷只使用 `if ... return 503`，不在 nginx rewrite 階段混入複雜代理邏輯。

計畫維護使用持續存在的旗標 `/etc/nginx/site-maintenance.flag`。下面是在 Linux A 上操作的範例命令，**沒有在目前 Windows 工作環境執行**：

```bash
# 修改設定後，先檢查，再重新載入。
sudo nginx -t
sudo systemctl reload nginx

# 進入維護，旗標以每次請求檢查，不需為旗標變動 reload。
sudo touch /etc/nginx/site-maintenance.flag

# 完成升級、必要依賴與資料確認後，解除維護。
sudo rm -- /etc/nginx/site-maintenance.flag
```

此命令只移除指定旗標，不刪除目錄。`/etc` 旗標會跨重開機保留；解除前，外部監控應繼續判 A 不可用。若使用 `/run` 旗標則通常重開機會消失，須確認這是否符合部署流程。

計畫升級應先設旗標，再排空正在執行的請求或暫停接收新交易，之後才停止程式。旗標只能阻擋新請求，不能撤回已開始的付款或資料寫入。升級結束後，先直接測試程式的健康端點，再解除旗標，最後確認正式域名恢復。

模板只處理 reverse proxy。若現有站點是 PHP-FPM，需改用 `fastcgi_intercept_errors on` 搭配相同的錯誤頁設計；不能只增加 `proxy_intercept_errors` 就期望 FastCGI 同樣生效。[nginx FastCGI 設定](https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html#fastcgi_intercept_errors)

## 定義真正能代表 A 可服務的探針

建議 A 的應用程式提供 `/readyz`：正常且可接流量才回 200，維護或必要依賴失效回 503。回應可帶一個固定識別值及版本；必要時使用字串比對避免 SPA fallback、登入頁或維護 HTML 的 200 被誤認健康。

| 檢查 | 能知道什麼 | 仍漏掉什麼 |
| --- | --- | --- |
| ping | 部分網路連通性 | TCP、TLS、nginx、程式與業務依賴 |
| TCP 443 | 能建立 TCP 連線 | TLS 憑證、HTTP 與應用健康 |
| HTTPS 靜態 `/livez` | HTTP 入口仍可回答 | 程式或 DB 可能已壞 |
| 應用 `/readyz` | 程式與必要依賴可接流量 | 探針未涵蓋的交易或部分功能 |
| 登入與唯讀查詢的合成測試 | 更接近使用者功能 | 複雜度、帳號維護與誤觸寫入風險 |

readiness 檢查應短、無副作用、不可快取，也不回詳細機密。避免每次探測執行昂貴全表查詢或建立真實訂單。只把「沒有它就不能提供核心功能」的依賴列為硬條件；例如報表系統壞了不一定要讓登入整站下線。

外部探針直接指定 A 的來源 IP 或不會切換的來源域名，並設定正確 Host、TLS server name 與憑證驗證。若主站前有 CDN，檢查主站網址很可能在看快取或 B，無法代表 A。監控來源 IP、防火牆、認證及 HTTPS 行為都要按所選服務確認。[Route 53 探測欄位](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/health-checks-creating-values.html)

## 外部 HTTP 主備入口

### 使用託管 LB

1. 建立主要 pool A 與次要 pool B，使用各自固定來源位址，不把外部入口本身當作回源地址。
2. 為 A 加有意義的 `/readyz` monitor；B 只顯示維護頁時使用[維護來源模板](../examples/nginx-b-maintenance-only.conf)，探測 B 的 `/readyz`，不要探測預期回 503 的首頁。
3. 設定 primary-first 的主備政策。Cloudflare 的例子使用 `Off — Failover`，pool 順序 A 再 B，並配置 monitor；只有排序而沒有健康檢查不足以保證這種切換。
4. 設定正常及故障的逾時、失敗與成功門檻。若產品不提供穩定觀察期，讓 A 在準備完成後才回 readiness 200。
5. 確認 fallback pool。Cloudflare 的 fallback 是所有正常池失效時的最後目的地，其健康狀態不會阻止路由送往它；不能把名稱含 fallback 當作必定健康。[Cloudflare 健康與 fallback](https://developers.cloudflare.com/load-balancing/understand-basics/health-details/)
6. 同一正式域名的對外 TLS 由入口處理；入口到 A/B 仍使用正確 HTTPS 驗證或受保護私網。設定防火牆、真實來源 IP 與信任範圍。
7. 若希望新請求恢復後全部優先走 A，不開不必要的 session affinity，也不讓 B 回永久轉向。不要快取動態維護回應、API 或帶個資的內容。
8. 測試後將正式 DNS 指向入口，保留設定備份、原記錄與回復程序；不能在第一次真實事故才建立這個入口。

不能把 upstream 5xx 一律歸到故障：503 可能是維護、502 可能是應用未起來，500 可能是某個特定程式 bug，404 可能只是合法查無資料。需明確決定哪些錯誤要轉頁、哪些錯誤要退池、哪些應直接回客戶端。

### 使用自建 C nginx 或 HAProxy

[外部 nginx 主備模板](../examples/nginx-external-primary-backup.conf)必須放在 **C**，不是 A。它採 HTTPS 回源，兩來源皆持有 `example.com` 的有效憑證，A primary、B backup；讀取路徑有有限的重試，API 停止同一請求跨來源重試。C 也準備本機維護頁，A/B 都無法回答時仍有訊息。

此模板的 failover 與 failback 是**被動**的：真實請求讓 A 達失敗門檻後，暫時改走 B；`fail_timeout` 過後再有流量時可以重試 A。A 成功則新的選擇恢復 primary；沒有流量就不會預先證明 A 已恢復。它沒有主動 readiness、連續 5 次成功或資料角色檢查的能力。[nginx 被動健康檢查](https://docs.nginx.com/nginx/admin-guide/load-balancer/http-health-check/)

若必須主動探測 A、可調 `fall`／`rise` 成功失敗次數、持續檢查復原狀態，可選開源 HAProxy 主動健康檢查，或託管 LB。nginx OSS 自己加外部控制器也能做，但要承擔 reload、狀態同步與控制器故障處理。C 本身的可用性另行規劃。

### 只有 A 與 B 時讓 B 永遠當入口

以 A 本地模板的錯誤頁邏輯放到 B，將 `proxy_pass` 改成 A 的獨立 HTTPS 来源域名，DNS 固定指向 B。A 的回源域名不能再解析回 B，否則代理會形成迴圈。

例如回源使用 `https://origin-a.example.com`，A 接受正確業務 Host；B 的代理設定須開 `proxy_ssl_server_name on`、`proxy_ssl_name origin-a.example.com`、`proxy_ssl_verify on` 與實際 CA bundle。A 的憑證應涵蓋該 SNI 名稱。HTTP Host 決定站點，TLS SNI 與驗證名稱決定憑證，兩者不能混為同一欄位。

B 的錯誤處理在本機完成。一般請求都先代理 A，A 恢復後新的成功請求直接拿到 A 內容，所以不需要把 DNS 改回 A；入口本來就固定在 B。A 未恢復時每次連線嘗試的逾時會影響維護頁速度；若要暫時跳過 A，需加斷路器或主動健康控制，而不是無限制等待。

此設計的一份靜態 `proxy_pass` 來源域名通常在載入設定時解析；A 的來源 IP 變動時要處理重新解析或 reload。TLS、來源實際可達性與轉送協定需一起測試。若只是 B 跟 A 的私網 HTTPS 互連，仍要驗證憑證。

## DNS failover 的設定流程

1. 準備 B 的維護服務、正式域名 HTTPS 憑證與各路徑回應；讓 B 長期保持可用，不依賴事故發生後人工開機。
2. 配置外部健康檢查直接探測 A 的固定位址與 `/readyz`，驗證 Host、協定及回應內容。確認不會被 CDN 快取或 B 代答。
3. 在支援 failover 的權威 DNS 為同名同型記錄建立 primary A 與 secondary B；IPv4 與 IPv6 分別按實際能力設定。不支援 IPv6 備援時，須先妥善移除不受保護的 AAAA，而不是事故時才忽略它。
4. 可把 TTL 60 秒作為試驗起點，但應提前降低原記錄 TTL，等待原 TTL 已經過去；事故時才改短 TTL 不會清掉舊快取。此值是建議起點，不是保證或必要值。
5. 決定是否替 B 掛 routing health check。若不掛，primary 壞時會回答 B 即使 B 也壞；若 A/B 都掛，兩者都壞時 Route 53 的 failover 政策會回 primary。應按實際需求演練，而不是只驗證 A 單獨失敗。[Route 53 回答政策](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/health-checks-how-route-53-chooses-records.html)
6. 若更換權威 DNS，先完整搬移現有 MX、TXT、CAA、子網域等記錄，檢查 DNSSEC 與原 DS 記錄相容，避免只搬網站 A 記錄而傷及郵件或其他服務。
7. 從多個獨立網路與解析器量測切換、恢復；記錄權威回答已改變的時間及實際訪客請求到哪台，不以單次本機 `dig` 當全面驗收。
8. A/B 的憑證續期不應依賴「目前一定輪到這台接 HTTP challenge」；依部署採 DNS challenge、獨立驗證路徑或可靠分發。切换後 HSTS 網站也必须提供有效 HTTPS。

如果使用外部監控程式呼叫 DNS API，控制器放 B 或另一個獨立服務；它持續直接檢查 A，維護當前狀態、主優先政策和回切觀察期，只在狀態轉換時更新記錄。限制 API token 到必要 zone/記錄，處理更新失敗、重試、重複控制器與讀回確認。A 不可是唯一執行者。

## 邊緣直接回維護頁的設計

若不需要完整 B，可將維護 HTML／JSON 預先包進 Worker 或 CDN 的錯誤資產。Worker 的概念流程是：

```text
收到請求
  計畫維護鎖已開 → 回 503 HTML 或 JSON
  否則嘗試 A，受明確的等待限制
    A 正常 → 回原回應
    來源連線、TLS 或指定可用性錯誤 → 回 503 維護訊息
  未識別的業務錯誤 → 保留原錯誤語意
```

這是設計流程而非可直接部署的 Worker 程式。實現時需避開遞迴路由、Host／SNI 不合、請求 body 的重讀與不同協定限制；邊緣程式自身執行錯誤、額度超限或供應商整體故障仍可能無法顯示自訂頁面。

若每次都先試 A，故障期間每個請求都可能等待逾時。要縮短這段時間，可使用集中健康狀態或斷路器，並持續安排有限的恢復探測。多個邊緣節點的記憶體不是自動共用的健康資料庫，狀態更新的一致性、期限與例外要明確。

不要在 Worker 中把未知結果的 POST 自動送 B。若需要 HTTP API 的完整備援，採健康檢查決定後續新請求的來源，再由應用定義冪等、重試與結果查詢。CloudFront 原生來源 failover 的方法限制也需要依業務拆分，而不是開啟後就當全部 API 有備援。

## 驗收情境

應在受控測試環境進行；整台斷電、網路丟包與資料故障測試需有主控台、設定備份及可回復方式。下面是待執行的驗收清單，不是已通過的測試紀錄。

| 情境 | 驗收結果 | 要留下的證據 |
| --- | --- | --- |
| 正常狀態 | A 提供正常頁面與 API，B 不承接不必要流量 | 回應碼、來源標識、入口及 A/B 日誌 |
| 計畫維護旗標 | HTML 503、API JSON 503、A readiness 非 200 | 標頭、內容類型、頁面與監控狀態 |
| 停止 A 的應用 | A nginx 本地維護頁或外部入口走 B | 第一個失敗、切換、回應的時間 |
| A 回 503 | 依設定顯示頁面或退出 primary | 錯誤攔截與探測結果 |
| A 回合法 401、404、422 | 保留业務狀態，不被全部誤改成維護 | 原回應與客戶端顯示 |
| A 回 200 但缺指定健康內容 | 有內容驗證時應判不健康 | 探針匹配結果 |
| 停止 A 的 nginx | 外部入口或 DNS 備援依然能提供訊息 | 訪客端結果、入口日誌 |
| 關閉測試 A 整台或封鎖來源 | 不靠 A 程式即可轉到 B | B 日誌、外部 health 狀態、切換時間 |
| A TCP 拒絕與 A 網路丟包 | 都能處理；丟包通常等待較久 | 兩種失敗各自的延遲 |
| 必要 DB 失效，port 仍開 | A readiness 失敗；不誤判健康 | DB 狀態、readiness 與路由變化 |
| A 來源 TLS 錯誤 | 外部入口可回頁；訪客直接連 A 時仍可能被 TLS 阻擋 | 入口與直連行為差別 |
| B 首頁 503、B readiness 200 | LB 知道 B 的維護角色可用 | B 探針與正式頁面的兩種狀態 |
| A 與 B 同時不可用 | 外部入口本地頁或產品的預期故障結果 | fallback 路由及對外錯誤 |
| A 恢復但維護旗標還在 | 不能提早回切 | A 探測狀態與旗標 |
| A 健康完成放行 | 新流量回 A；DNS 方案分別量測快取等待 | 權威 DNS、各客戶端及來源日誌 |
| A 反覆好壞 | 不因一個瞬間 200 就頻繁切回 | 失敗成功門檻與觀察期事件 |
| GET 與交易 POST | GET 可按策略備援；POST 不被任意重播 | 同一交易識別碼在 A/B 的執行次數 |
| 已送出回應後中斷、SSE 或 WebSocket | 正確認知無法無縫搬移；客戶端可重連 | 重連及結果查詢紀錄 |
| 帶 query 的深層網址與 `/api` | 正確頁面、JSON 與原網址，無永久轉向 | Content-Type、status、Location |
| IPv4、IPv6 與數個獨立網路 | 無漏掉仍指向故障 A 的位址 | A/AAAA 回答與來源命中 |
| A 恢復後 CDN 快取仍在 | 設定可使維護內容失效，不持續給舊頁 | Age、Cache-Control、CDN 快取狀態 |
| 完整備援 B 有新寫入 | A 資料核對完成前不放行回切 | 複寫落後、角色、fencing 與回補紀錄 |

Linux 測試命令範例：

```bash
curl -i https://example.com/some/deep/path?check=1
curl -i -H 'Accept: application/json' https://example.com/api/health-test
curl -i --resolve example.com:443:192.0.2.10 https://example.com/readyz
curl -i --resolve example.com:443:198.51.100.20 https://example.com/readyz
dig example.com A
dig example.com AAAA
```

`--resolve` 是繞過 DNS 測指定來源，同時保留 URL 的 Host 與 TLS 名稱；範例 IP 需替換。如果原站只允許 CDN 或探針 IP，需從被允許的測試路徑執行，不能因測試被防火牆擋住就判定程式不健康。Windows PowerShell 使用 `curl.exe` 可避免舊版別名差異。

## 最小落地順序

1. 先決定 B 只顯示訊息，還是完整服務；設定可接受的故障與回切等待時間。
2. A 增加本機 503 HTML、API JSON、維護旗標與真實 readiness。
3. 選外部 HTTP 入口、DNS failover，或固定 B 入口；完成來源 HTTPS 及 B 頁面。
4. 先驗證 A 壞了會切換，再驗證 A 好了會回切，以及兩端同時壞、IPv6、快取和長連線。
5. 將維護流程、觀測與定期演練納入操作手冊。

只完成第 2 步，保護的是程式層；完成外部入口與演練後，才有涵蓋 A 整機故障的證據。
