# 現有 Keycloak 部署盤點

[回主報告](../README.zh-TW.md) · [盤點步驟](../research/04-keycloak-deployment.zh-TW.md)。最後更新：2026-10-12。

已知：使用者已有 Keycloak，表示使用「最新版」，忘了當初如何架設。以下空白項目均未確認，不把研究參考版 26.8.0 當成已安裝版號。

本表只記錄非秘密資訊與秘密的保管位置；不要填入 client secret、密碼、token、private key、完整 Realm export 或個人資料。若主機名稱、網路拓撲與內部路徑屬於私密資訊，另存 Git 之外的私人紀錄，不填入公開研究庫。

| 項目 | 現況 | 驗證方式／位置 |
| --- | --- | --- |
| 實際 Keycloak 版號 | 待確認；使用者表示最新版 | Console／`kc.sh --version`／映像 |
| 主機與維護負責人 | 待確認 | VPS／VM／雲端管理平台 |
| 部署方式 | 待確認 | Compose／Operator／Helm／systemd／Windows service |
| 啟動檔與原始設定位置 | 待確認 | 非秘密路徑；GitOps repository |
| 映像標籤與 digest | 待確認 | registry／容器 image ID |
| 登入域名與 issuer | 待確認 | Discovery |
| context path | 待確認 | `/` 或 `/auth` 等 |
| 正式 Realm 與用途 | 待確認 | 不公開內部名稱時另存 |
| DB 種類與版本 | 待確認 | DB 管理平台 |
| DB persistence 與 HA | 待確認 | Volume／PVC／managed DB |
| DB 帳號／密碼保管位置 | 待確認 | 僅秘密管理服務名稱 |
| proxy／LB 與 TLS 模式 | 待確認 | edge／re-encrypt／passthrough |
| 外部與內部連接埠 | 待確認 | 防火牆／Ingress／容器 |
| 管理入口限制 | 待確認 | VPN／ACL／私網 |
| 管理員與復原保管人 | 待確認 | 記錄職責，勿填個人認證資訊 |
| MFA 與 recovery 方式 | 待確認 | 登入流程及保管程序 |
| 自訂 theme／SPI | 待確認 | 程式版本、建置來源 |
| LDAP／外部 IdP | 待確認 | 類型與來源，不填憑證 |
| Client 應用清單 | 待確認 | app 類型、issuer、用途、負責人 |
| 備份時間與存放位置 | 待確認 | DB／外部檔案／異地副本 |
| 最近還原演練 | 待確認 | 日期、RPO、RTO、驗收結果 |
| 監控與日誌 | 待確認 | 保留期、告警接收責任 |
| 上次升級與回復方案 | 待確認 | 變更紀錄 |
| 優先整合應用 | 待確認 | 程式語言／框架／SaaS |

盤點完成的條件：能說明「在哪台主機以哪份設定啟動哪個映像、連向哪個 DB、如何對外提供 issuer、誰能管理、如何還原」。只有網址與 admin 密碼尚不足以維護。
