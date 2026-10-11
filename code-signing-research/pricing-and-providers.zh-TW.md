[English](pricing-and-providers.md) | **繁體中文** | [驗證文件](README.zh-TW.md)

# OV Code Signing 價格、短期方案與通路評價

查證日期：2026-10-11，Asia/Taipei。範圍為一般 Windows Authenticode 公司簽章；不是網站 TLS、Apple Developer ID 或 Windows 核心驅動程式認證。金額以官網公開頁為準，尚未取得正式報價或實際結帳。除註明外美元價格未含適用稅、匯差及國際運費。

## 結論

US$150 內有公開標示包含雲端簽章的方案：My-SSL 的 Certum Standard／SimplySign，1 年 US$99，2 年總額 US$149。但是通路的公開投訴集中於核發、支援與退款，不能直接當成可靠低價首選。Standard 同時接受個人與公司，申請時必須選公司身份並完成組織驗證，不能以 IV 代替公司 OV。[產品與價格](https://my-ssl.com/code-signing)

SSL.com US$129 是一年憑證費，持續雲端簽章另付 eSigner。最低年繳方案 US$180，因此一年憑證加一個完整年度的基本雲端訂閱為 US$309。SSLmentor 的 Certum 雲端一年 US$177 是接近預算的另一個比價候選；本次沒有完成其獨立服務評價調查，不據此保證支援品質。[SSL.com 憑證](https://www.ssl.com/products/software-integrity/code-signing/ov/)、[eSigner 費率](https://www.ssl.com/guide/esigner-pricing-for-code-signing/)、[SSLmentor](https://www.sslmentor.com/certum/certumcodecloud)

## 十個購買選項

這是購買選項比較，包含 CA 直售及經銷通路，不是十家獨立 CA，也不是市占率排名。分組列出可核實的雲端組合與仍需補報價的選項；不能只按憑證標價做總成本排名。價格可能因促銷、地區、結帳及產品設定改變。

| 編號 | 通路／商品 | 公開價格 | 包含及限制 | US$150 內完整方案？ |
| --- | --- | --- | --- | --- |
| 1 | [My-SSL／Certum Standard Cloud](https://my-ssl.com/code-signing) | 1 年 US$99；2 年總額 US$149 | SimplySign 雲端，無 USB Token；適用稅另計；須 CA 核准公司申請 | 標示符合；核發與服務風險需考量 |
| 2 | [SSLmentor／Certum Cloud](https://www.sslmentor.com/certum/certumcodecloud) | 1 年 US$177；2 年總額 US$264 | 含雲端；未含 VAT；通路列每月上限 5,000 次及每次登入 2 小時操作期間 | 一年不符合；2 年平均 US$132／年不代表只付 US$132 |
| 3 | [SSL.com OV＋eSigner](https://www.ssl.com/products/software-integrity/code-signing/ov/) | US$129＋US$180＝US$309 | 一年憑證＋一年基本雲端；240 次／年，超額 US$1／次；另有首 30 天免費試用 | 持續一年雲端不符合 |
| 4 | [GoGetSSL Cloud／DigiCert](https://www.gogetssl.com/sslcerts/cloud-codesigning-ssl/) | 1 年 US$425 | 雲端、1 個使用席位、包含 1,000 次簽章 | 不符合 |
| 5 | [Certum 官方 Cloud](https://shop.certum.eu/standard-code-signing-in-the-cloud.html) | 頁面起價 €209 | SimplySign；動態選項未取得確定一年結帳總額，頁面庫存文字也不一致 | 未取得 US$150 內報價 |
| 6 | [CheapSSLsecurity／FastSSL，DigiCert](https://cheapsslsecurity.com/fastssl/code-signing-certificate.html) | 一年憑證 US$149 | 必選交付方式；沒有核實含 Token、雲端或自備 HSM 的完整費用 | 僅憑證價符合，總額未證實 |
| 7 | [SignMyCode Windows OV](https://signmycode.com/windows-code-signing) | 一年憑證 US$299.99 | Token／國際交付或自備 HSM 另確認；2、3 年方案限定既有 HSM | 不符合 |
| 8 | [SSL2BUY／Sectigo OV](https://www.ssl2buy.com/sectigo-code-signing-certificate.php) | 一年憑證 US$300 | 廣告 US$225／年需買 3 年，總額 US$675；交付方式費用另確認 | 不符合 |
| 9 | [DigiCert 官方＋KeyLocker](https://www.digicert.com/buy) | 需確認正式報價 | 公開頁同時顯示 US$65／月和 US$996 年總額，數字不一致；明列 12 個月自動續約，含 1,000 次／年 | 不符合已知預算；月價不是短期契約證據 |
| 10 | [GlobalSign 官方 OV](https://www.globalsign.com/en/code-signing-certificate) | 詢價 | 未取得可核實的現行總額；Token／HSM 及運費依正式方案確認 | 未找到符合報價 |

多年的價格是服務購買期間，不能當成一張憑證多年有效。各 CA 的實際憑證期限及重發程序以其現行政策為準。本次不換算歐元，以免混淆匯率及結帳費用。SimplySign 的操作驗證也不能直接推定適合無人值守 CI/CD。[Certum 有效期與重發說明](https://shop.certum.eu/standard-code-signing-in-the-cloud.html)

## 為什麼沒有列市占率前十名

本次沒有找到可核對的 2026 全球「OV Code Signing 憑證」市占率前十與一致分母。網站 TLS 的市占率不適用；經銷商不能當成另一家 CA 重複計算。

NDSS 2026 論文 Understanding the Status and Strategies of the Code Signing Abuse Ecosystem 有依已簽署 PE 檔案樣本比較 CA 的分布，但它不是目前 OV 憑證銷售量、營收或全球所有發行者的調查。不能將樣本占比直接寫成採購市占排行榜。[原始論文](https://www.ndss-symposium.org/wp-content/uploads/2026-f2857-paper.pdf)

## 半年或更短的付費方式

本次核實的傳統公司 OV 憑證公開購買選項未找到半年或更短方案；可月繳的雲端服務，仍可能搭配一年憑證或一年契約。

SSL.com 基本 eSigner 月繳 US$20，含每月 20 次，超額 US$1／次；首 30 天免費且不限次數。若搭配一年 US$129 憑證：6 個付費月為 US$249，1 個付費月為 US$149。這是費用算式，不是六個月或一個月的憑證，也不是已確認可保留有效憑證的取消方案。試用起算、實際收費月數及既有訂單適用價格以帳戶為準。[官方費率](https://www.ssl.com/guide/esigner-pricing-for-code-signing/)

官方取消指引使用 REVOKE：若憑證只存在 eSigner 雲端，取消流程會撤銷整張憑證，恢復需重發。不能把「先簽完，再取消」描述為保留有效憑證的省錢方式，也不能保證已有時間戳的檔案不受撤銷影響。若要短期使用，先取得 SSL.com 對不撤銷暫停方式及既有簽章驗證結果的書面說明。[取消指引](https://www.ssl.com/how-to/how-to-cancel-esigner-subscription/)

Microsoft Azure Artifact Signing（原 Trusted Signing）Basic 為 US$9.99／月，含 5,000 次，六個月 US$59.94，未計超額及其他 Azure 用量。但 Public Trust 組織資格清單目前沒有台灣；不能靠把 Azure 資源選在美國區域改變公司資格。Private Trust 不適用作一般對外軟體發行的公開信任替代品。這是託管簽章服務，不是傳統自行持有的 OV 憑證。[官方價格](https://azure.microsoft.com/en-us/products/artifact-signing)、[組織資格](https://learn.microsoft.com/en-us/azure/artifact-signing/quickstart)

## My-SSL 與 SSL.com 的評價

| 查閱時的 Trustpilot 資料 | My-SSL | SSL.com |
| --- | --- | --- |
| 分數／樣本 | 2.3／5，6 則 | 4.9／5，3,667 則 |
| 可見經驗 | 包含購買 Standard Code Signing 後核發未完成、客服及退款延遲的投訴 | 有 code signing 支援及驗證正評，也有個人簽章核發延遲、退款及帳務投訴 |
| 解讀 | 樣本很小，但不宜忽略反覆的服務問題訊號 | 整體服務評價較強；涵蓋 TLS、S/MIME 等商品，不能視為 OV 成功率 |

來源：[My-SSL 用戶評論](https://www.trustpilot.com/review/my-ssl.com)、[SSL.com 用戶評論](https://www.trustpilot.com/review/ssl.com)。平台也提示評價可能不具代表性。投訴是用戶陳述，本次沒有核實其訂單或判定詐欺；不能由六則負評推定所有客戶失敗，也不能由高分保證核發順利。

My-SSL 是販售 Certum／SimplySign 的通路，核發 CA 與通路客服應分別看待。其退款頁列營運者 Verifold LLC，並依 Paddle 或其他付款服務區分退款條款；付款前確認適用條款、台灣公司與證件資格、含雲端的總額以及多年重發費用。[退款政策](https://my-ssl.com/refund-policy)

判斷：對有交付期限的公司申請，本次證據不足以推薦 My-SSL 作首選；SSL.com 可以列入可用候選，但須把雲端費用、超額及取消處理納入預算。若 US$150 是硬上限，My-SSL 的公開價格符合，卻不能因此忽略服務風險；若可提高到 US$177，SSLmentor 的 SimplySign 組合值得取得正式報價及查核服務條款。

已買 SSL.com 的情況，應先看實際訂單的金鑰儲存方案與後續簽章需求，再決定續辦或退款。改用 Certum 仍需組織與申請人驗證，不會自動免除補文件。
