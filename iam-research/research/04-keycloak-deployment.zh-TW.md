# Keycloak 部署盤點與架設

[回主報告](../README.zh-TW.md)。查核日期：2026-10-12。官方文件參考版本：26.8.0；現有安裝版號待確認。

你已經有可用服務，但忘了原本如何架設。第一步是找出部署與持久化資料的關係；不要為了熟悉流程就重建容器、更新映像、執行 Realm import 或重設資料庫。

## 找回原始架設方式

先從瀏覽器書籤、網域 DNS、主機管理平台與既有筆記找 Keycloak hostname。記錄登入網址、realm、管理入口及誰能登入主機；找得到 Admin Console 時查看版本資訊，但不要將管理主控台能開啟當作備份存在的證據。以[盤點範本](../templates/current-deployment.zh-TW.md)記錄結果。

以下命令在實際部署的主機執行；在你的個人電腦沒找到容器，不能推斷遠端服務不是 Docker。命令只讀，輸出仍可能含內部名稱和路徑，分享前去識別。

### Docker 或 Compose

```powershell
# 列名稱、映像、狀態、連接埠，不輸出環境變數
docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
docker compose ls

# 先將名稱換成上一步確認的 Keycloak 容器
$iamContainerName = 'replace-with-confirmed-container-name'
docker inspect --format '{{.Config.Image}}' $iamContainerName
docker inspect --format '{{.Image}}' $iamContainerName
docker inspect --format '{{json .Mounts}}' $iamContainerName
docker inspect --format '{{index .Config.Labels "com.docker.compose.project.working_dir"}}' $iamContainerName
docker inspect --format '{{index .Config.Labels "com.docker.compose.project.config_files"}}' $iamContainerName
docker exec $iamContainerName /opt/keycloak/bin/kc.sh --version
```

最後一條只適用含該路徑的 Keycloak 容器；舊 WildFly 發行版可能沒有 `kc.sh`，應依映像標籤、啟動日誌與舊版本文件核對。`latest` tag 不足以證明容器版號；同時記錄實際 image ID／registry digest。不要把完整 `docker inspect` 或 `docker compose config` 輸出貼到公開文件，裡面可能包含密碼。

### Kubernetes

```text
kubectl get pods -A -l app=keycloak
kubectl get deployments,statefulsets -A
kubectl get ingress -A
```

第一個標籤查詢沒有結果時，可能只是標籤不同；從已知 namespace 與 workload 名稱確認。接著記錄容器 image、PVC、Service、Ingress 與 Secret 的名稱和保管責任；不把 Secret 值輸出。Operator／Helm／GitOps 的原始設定是後續變更入口。

### VM 或系統服務

Linux 可先用 `systemctl list-units --type=service --all` 找服務名稱；Windows 可用以下查已註冊服務。自訂名稱可能不含 keycloak，沒結果就從管理平台與原始配置確認。

```powershell
Get-Service | Where-Object { $_.Name -match 'keycloak' -or $_.DisplayName -match 'keycloak' } |
    Select-Object Name, DisplayName, Status
```

確認安裝目錄後執行對應 `kc.sh --version` 或 `kc.bat --version`。檢查 service definition、`conf/keycloak.conf`、啟動參數與部署檔中的「設定名稱」，但秘密只記錄保管位置。反向代理可能在別台主機或外部 Load Balancer，不能只看本機程序。

## 判定可維護的最低資訊

| 要找出的資訊 | 為什麼必要 |
| --- | --- |
| hostname、context path、realm issuer | callback、token 驗證與遷移時要一致 |
| 實際版號、映像 digest、theme／SPI | 重建與升級相容性 |
| 啟動方式、設定來源與變更負責人 | 避免手動變更被下一次部署覆蓋 |
| DB 種類、版本、位置、帳號保管位置 | 帳號、設定與還原的依據 |
| Volume、PVC、外掛、TLS、signing key 保存方式 | 容器消失後仍能重建 |
| proxy 與可信來源、暴露連接埠 | 排查 origin、IP、TLS 與安全邊界 |
| 備份時間、內容、異地副本、還原步驟 | 確認服務真正可復原 |
| 正式管理員、MFA 與緊急存取 | 防止單一帳號或上游 IdP 故障鎖死 |

## 建立獨立實驗環境

附有[Compose 實驗範例](../examples/keycloak-lab/README.zh-TW.md)，使用獨立 PostgreSQL、Keycloak 映像與新的 `iam-lab` Realm。只綁定 loopback 的 HTTP／management port，供本機學習，不能當公開正式部署。不要連到現有 DB，也不要匯入現有 Realm。

研究環境沒有 Docker，範例尚未進行容器建置與端到端登入驗證；需要在具備 Docker 的測試主機依附帶步驟執行。Keycloak 的 DB 文件將 PostgreSQL 17.x 列為支援版本；範例仍須在實際採用的 patch／digest 下驗收。[Database](https://www.keycloak.org/server/db)。

## 正式架構

建議按可用性要求決定單節點或叢集，架構為「Browser／App → TLS proxy／LB → Keycloak → PostgreSQL」，並由私有管理網路接監控與管理入口。只有登入需要的端點對外；DB 與叢集通訊留在私網。

單節點和本機 DB 都是故障單點。若要求節點故障仍能登入，需要多個 Keycloak 節點、相容的快取／節點發現設定及 DB HA；跨節點登入、重啟與網路分裂都要測。不要只啟動兩個容器就宣稱 HA，也不要跨區拉長快取網路後假定效能不變。[Distributed caches](https://www.keycloak.org/server/caching)、[HA guide index](https://www.keycloak.org/guides#high-availability)。

## 生產模式與 TLS

用固定版本和 digest 建立映像，必要的 health、metrics、DB 與 provider 在 build 階段設定；正式執行 `start --optimized`，不使用 `start-dev`。Bootstrap 管理員僅供首次建立或復原，接著建立正式管理員、驗證 MFA 並移除暫時帳號。[Container guide](https://www.keycloak.org/server/containers)。

以下是一份 **TLS re-encrypt 設計示意**，只列非秘密配置；cert、key、DB 密碼由部署平台注入。代理端必須驗證 Keycloak 的內部憑證。

```text
KC_DB=postgres
KC_DB_URL=jdbc:postgresql://db.internal.example:5432/keycloak
KC_DB_USERNAME=keycloak
KC_HOSTNAME=https://sso.example.com
KC_HOSTNAME_ADMIN=https://sso-admin.example.com
KC_HTTPS_CERTIFICATE_FILE=/run/tls/tls.crt
KC_HTTPS_CERTIFICATE_KEY_FILE=/run/tls/tls.key
KC_PROXY_HEADERS=xforwarded
KC_PROXY_TRUSTED_ADDRESSES=10.20.0.10/32
```

上面的可信 IP 只是佔位，必須改為真實 proxy 來源並搭配防火牆。管理域名改名不會阻擋從公開 hostname 訪問 Admin API；代理／網路 ACL 必須另做隔離。[Hostname](https://www.keycloak.org/server/hostname)。

現有環境若是 edge TLS termination（proxy 到 Keycloak 走 HTTP），需依該部署設定 `KC_HTTP_ENABLED=true`，並限制後端網路；這是有條件的拓撲選擇。官方 proxy 文件區分 re-encrypt、edge 與 passthrough；proxy 必須覆寫 forwarded headers，Keycloak 只接受可信 proxy 來源。9000 不公開代理；passthrough 不搭配 HTTP forwarded headers。[Reverse proxy](https://www.keycloak.org/server/reverseproxy)。

## 容量與依賴

先在測試環境量測登入、refresh、MFA、broker、管理與停權的負載。預算必須包含 DB 連線、記憶體、CPU、郵件與上游 IdP 延遲；密碼雜湊是登入 CPU 成本的重要來源，不能為追求測試吞吐量擅自降低保護設定。

health 和 metrics 在優化映像 build 階段啟用，分別使用 readiness 與 liveness。正式監控請另外檢查 DNS、TLS、broker 與 SMTP；節點 `/health/ready` 回應成功並不證明所有實際登入流程成功。[Health](https://www.keycloak.org/observability/health)、[Metrics](https://www.keycloak.org/observability/configuration-metrics)。

## 實施順序

1. **找回現況**：填盤點、確認 DB、實際版本、部署來源與管理員。
2. **先有復原能力**：備份 DB／外部設定／密鑰，在獨立環境還原。
3. **補安全與可觀測性**：TLS／proxy、管理入口、MFA、事件日誌、health／metrics。
4. **接第一個應用**：獨立 Client、Code + PKCE、audience、角色、登出與停權驗收。
5. **再接企業來源與佈建**：帳號映射、生命週期與來源故障備援。
6. **最後按需求擴展**：HA、容量、GitOps 與自動化；每次變更均保留回復路徑。
