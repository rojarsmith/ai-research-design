# 網站維護與故障切換來源及查核條件

[返回主研究](../README.zh-TW.md)。查核日期：2026-10-12，Asia/Taipei。

以下使用協定標準、官方軟體文件與產品文件確認功能及公開費率。官方文件可證明產品提供的機制與條件，不能直接證明你目前主機已经通過故障切換。架構適用性、工時、VPS 預算及選型建議屬於條件式工程分析。

## 協定與維護回應

| 來源 | 支持的內容 | 判讀條件 |
| --- | --- | --- |
| [RFC 9110 HTTP Semantics](https://www.rfc-editor.org/rfc/rfc9110.html) | 503 與 Retry-After | 表示暫時無法提供服務與重試時間提示，不保證自動刷新或恢復 |
| [RFC 9111 HTTP Caching](https://www.rfc-editor.org/rfc/rfc9111.html) | Cache-Control no-store | 仍需檢查實際 CDN 與客戶端行為 |
| [Google 暫停網站指南](https://developers.google.com/search/docs/crawling-indexing/pause-online-business) | 短暫停站使用 503、長時間停用的搜尋影響 | 搜尋引擎處理建議，不是網站可用性 SLA |

## nginx 與獨立代理

| 來源 | 支持的內容 | 判讀條件 |
| --- | --- | --- |
| [nginx proxy 模組](https://nginx.org/en/docs/http/ngx_http_proxy_module.html) | 錯誤攔截、來源重試、讀取逾時、TLS 回源 | 核對現有 nginx 版本；非冪等請求和已送出回應的限制不可忽略 |
| [nginx upstream 模組](https://nginx.org/en/docs/http/ngx_http_upstream_module.html) | backup、max_fails、fail_timeout、zone | 機制作用於存活入口之後的上游，不保護入口本身 |
| [nginx core error_page](https://nginx.org/en/docs/http/ngx_http_core_module.html#error_page) | 內部錯誤頁與回應碼轉換 | 內部 URI 與 named location 的方法行為不同 |
| [nginx FastCGI 模組](https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html#fastcgi_intercept_errors) | FastCGI 錯誤攔截 | PHP-FPM 不適用只設 proxy 模組的做法 |
| [NGINX HTTP Health Checks](https://docs.nginx.com/nginx/admin-guide/load-balancer/http-health-check/) | OSS 被動檢查、Plus 原生主動檢查與 slow start 條件 | 不把 Plus 功能當成 OSS 內建功能 |
| [HAProxy Health Checks](https://www.haproxy.com/documentation/haproxy-configuration-tutorials/reliability/health-checks/) | 主動探測、HTTP 狀態及內容驗證、成功與失敗門檻 | 自建入口可用性仍需另做設計 |

## DNS 主備

| 來源 | 支持的內容 | 判讀條件 |
| --- | --- | --- |
| [Route 53 健康狀態如何影響回答](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/health-checks-how-route-53-chooses-records.html) | Primary 優先、secondary、兩者失敗及未掛健康檢查的政策 | 權威 DNS 回答改變不等於訪客快取立即失效 |
| [Route 53 health check 欄位](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/health-checks-creating-values.html) | 來源位址、Host、HTTP/HTTPS、探測條件 | 探測應直達來源；公開 endpoint 可達性和防火牆要驗證 |
| [Route 53 官方費率](https://aws.amazon.com/route53/pricing/) | Zone、標準查詢、Non-AWS 檢查與各選配功能 | 成本例採一般區域、100 萬 DNS 查詢與指定檢查數；不等於 HTTP 請求量 |

## CDN 邊緣與託管負載平衡

| 來源 | 支持的內容 | 判讀條件 |
| --- | --- | --- |
| [Cloudflare Custom Errors](https://developers.cloudflare.com/rules/custom-errors/) | Free 與付費方案的錯誤頁及規則差異 | 個別錯誤類型仍有功能限制；Workers 付費不是網站 Pro |
| [Cloudflare 標準 steering 與 failback](https://developers.cloudflare.com/load-balancing/understand-basics/traffic-steering/steering-policies/standard-options/) | Off 主備順序、A 恢復自動回切、affinity 例外 | 需有健康 monitor；既有連線不會自動遷移 |
| [Cloudflare pool 健康與 fallback](https://developers.cloudflare.com/load-balancing/understand-basics/health-details/) | Pool 健康、最後 fallback 不依健康阻止路由 | 不把 fallback 視為一定可用的保證 |
| [Cloudflare LB 快速設定](https://developers.cloudflare.com/load-balancing/get-started/quickstart/) | Pool、monitor、來源及設定流程 | 實際間隔與功能以購買配置為準 |
| [Cloudflare 官方方案](https://www.cloudflare.com/plans/) | Load Balancing 5 美元／月起 | 起價不是最終帳單；來源、監控區域與用量另外確認 |
| [Workers 官方價格](https://developers.cloudflare.com/workers/platform/pricing/) | Free requests、Paid 含量與超額費用 | 使用代理程式時，要計入正常網站流量與 CPU |
| [CloudFront origin failover](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/high_availability_origin_failover.html) | Primary/secondary、GET/HEAD/OPTIONS、先試 primary 與逾時設定 | POST/PUT 等不走原生 failover；快取命中另行判讀 |
| [CloudFront 錯誤快取](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/custom-error-pages-expiration.html) | 錯誤保存時間與標頭、最小快取時間的關係 | 需要依來源類型與 error TTL 實測回復速度 |
| [S3 website endpoints](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteEndpoints.html) | Website endpoint 不支援 HTTPS，可搭 CDN 等服務 | 不把 S3 REST HTTPS 與自訂網站 HTTPS 混在一起 |

## IP 搬移的網路條件

| 來源 | 支持的內容 | 判讀條件 |
| --- | --- | --- |
| [Hetzner Floating IP FAQ](https://docs.hetzner.com/cloud/floating-ips/faq/) | 可重新指派、跨位置仍受 network zone 限制 | 是該產品的範例，不能延伸為任意 VPS 或跨供應商支援 |

## 部署前要確認的實際參數

| 問題 | 為何影響方案 |
| --- | --- |
| A 的 VPS 供應商、機房與網路限制 | 浮動 IP 能否用、備援是否隔離故障範圍 |
| DNS 供應商、權威 NS、目前 TTL 及 DNSSEC | 是否有健康路由、遷移與快取等待 |
| 是否已有 Cloudflare／其他 CDN，代理是否啟用 | 入口能力、錯誤頁方案、回源與快取 |
| A 的 nginx 版本、現有 reverse proxy 或 PHP-FPM 設定 | 模組、指令、路徑及相容性 |
| B 是現有主機，還是準備新增 | 真正增量費用與維運負擔 |
| B 只顯示訊息，還是要登入及寫資料 | 從頁面備援轉成資料與應用高可用 |
| 同一網址、同一 IP、正常流量是否必須直達 A | 決定外部入口、DNS 或 B 固定入口是否合格 |
| 可容許的故障偵測及自動回切等待時間 | 不能用 DNS TTL 承諾所有訪客立刻切換 |
| session、DB、檔案、queue、排程與 webhook 在哪裡 | 完整備援及切回的資料安全條件 |
| IPv6、WebSocket、SSE、上傳、CORS 與第三方白名單 | 需要額外的路由與客戶端相容測試 |
| 月流量、请求數、地區、正常延遲與預算 | 計算 CDN、Worker、LB、跨區傳輸和備援容量 |

這些參數用於把研究方案收斂成實際部署，不影响「A 整台故障時入口決策必須在 A 外」的結論。現階段 nginx 範例是可審閱模板；正式配置的健康判定、TLS、DNS 快取與故障演練仍需對實際環境驗證。
