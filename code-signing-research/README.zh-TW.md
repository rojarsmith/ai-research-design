[English](README.md) | **繁體中文**

# SSL.com OV Code Signing 公司驗證文件

研究日期：2026 年 10 月 11 日，Asia/Taipei。申請主體為台灣上市公司全台晶像股份有限公司，股票代號 3038，統編 89261652，訂單英文名稱為 EMERGING DISPLAY TECHNOLOGIES CORP.。使用者已確認代表公司申請。本主題處理目前三個驗證文件欄位及後續回撥，不延伸為公司的產品或策略研究。

可先使用以下證據整理件，讓 SSL.com 驗證團隊沿來源網址查證。第一份已附公司官網公開的原始英文章程；其餘封面及 API 摘錄為申請用整理，並非政府核發的登記證明、鄧白氏報告或已簽署授權。是否接受經濟部與證交所資料，以及是否仍須補正式文件，由 SSL.com 決定。

## 三個上傳欄位

| SSL.com 欄位 | 已準備的 PDF | 內容與後續條件 |
| --- | --- | --- |
| Documentation of Legal Existence | [01 公司登記與原始英文章程](output/pdf/01-legal-existence-public-record.pdf) | 經濟部登記資料加公司官網原始 7 頁英文 Articles of Incorporation，共 10 頁。若指定核准函、政府認證章程或認證翻譯，仍需補指定正式文件。 |
| Documentation of Physical Existence | [02 地址公開資料](output/pdf/02-physical-existence-address-record.pdf) | 證交所公布的中英文地址與公司統編，並以政府登記地址交叉核對。公開地址不能單獨證實實際占用，驗證團隊可能要求其他資料。 |
| Documentation of Order Authorization | [03 第三方公司聯絡資料](output/pdf/03-order-authorization-contact-record.pdf) | 證交所公布的公司總機及地址，對應提示中的 third-party contact information。這份資料不證明特定申請人的授權，須配合 SSL.com 的回撥或其他確認。 |

如果 SSL.com 另外要求書面授權，可使用 [04 英文授權書空白範本](output/pdf/04-order-authorization-unsigned-template.pdf)，由公司實際有權核准的人填寫及簽署。它不是 SSL.com 官方表單；對方若提供指定表單，優先使用指定版本。不要上傳未填寫的範本。

## 已核對的公司資料

| 項目 | 查證結果 |
| --- | --- |
| 中文公司名稱 | 全台晶像股份有限公司 |
| 英文名稱 | EMERGING DISPLAY TECHNOLOGIES CORP.；政府英文公示頁將其標為進出口廠商英文名稱，未據此認定為章程所訂外文名稱 |
| 統編及股票代號 | 89261652／3038 |
| 登記狀態 | 核准設立 |
| 成立日期 | 1994-09-23；經濟部原始欄位為民國 0830923 |
| 目前登記機關 | 經濟部產業園區管理局；政府英文公示頁為 Bureau of Industrial Parks, MOEA。未據此回推 1994 年最初核准機關。 |
| 最後核准異動日 | 2025-06-04；資料擷取日為 2026-10-11，兩者不同 |
| 中文地址 | 高雄市前鎮區中一路5號 |
| 證交所英文通訊地址原文 | No. 5, Central 1st Rd., Qianzhen Dist.,KAOHSIUNG TAIWAN R.O.C |
| 證交所總機電話 | 07-8124832；國際撥號格式 +886-7-8124832，移除國內區碼前導 0 |
| 證交所出表日期 | PDF 採用的 JSON 為民國 1151010，即 2026-10-10；另下載的 CSV 為 1151011，即 2026-10-11，名稱、統編、中英文地址及總機一致 |

上述結果來自[經濟部英文公示頁](https://findbiz.nat.gov.tw/fts/company/89261652?fhl=en)、[經濟部公司基本資料 API 定義](https://data.gov.tw/dataset/22197)與[證交所公司資料 API](https://openapi.twse.com.tw/v1/opendata/t187ap03_L)。已下載的官方原始資料及雜湊紀錄在 `sources/`。英文公示頁的名稱連結是網頁查證結果；網站對直接下載及瀏覽器顯示安全驗證，因此沒有取得該頁的原始 HTML 或列印檔。

公司[英文治理頁](https://www.edtc.com/corporate-governance/)連結的[英文章程原始 PDF](https://www.edtc.com/wp-content/uploads/2025/08/Articles-of-Incorporation.pdf)最後列出的修訂日期為 2025-05-28；它是目前網站所連結版本，仍請公司行政確認無後續修訂。章程第一條使用 Emerging Display Technologies Corporation，訂單與進出口登記使用 EMERGING DISPLAY TECHNOLOGIES CORP.；此差異已在法人文件中註明，應由 SSL.com 確認憑證主體名稱。7 頁原稿已附在 01 的第 4 至 10 頁，沒有修改原稿。

申請人的姓名、職稱、公司 Email、分機及訂單編號未提供，不能從發言人或公開信箱推定。實際訂單地址與電話也尚未讀取，因此上述資料是比對基準，並非已確認訂單完全一致。

## 正確提交順序

1. 在 SSL.com 訂單核對公司英文名、統編、台灣地址與電話。地址拼音可以有常見差異，但街道、門牌、行政區與國家須指向同一地點；必要時請驗證團隊確認名稱及地址寫法。
2. 在三個欄位分別上傳 01、02、03。內有可點選網址及內嵌原始 JSON；01 另附公司發布的原始英文章程。不要描述為政府核發、認證翻譯或鄧白氏證明。
3. 用下方英文訊息向 SSL.com 提供來源，請驗證團隊確認是否接受。若要正式法人文件，向公司法務、財務或行政取得最新公司登記核准函／變更登記表／章程掃描本；是否需要英文認證翻譯，先依對方要求辦理。不要自行重寫歷史章程、代簽或套用政府樣式。
4. 安排總機能接到 SSL.com 驗證來電並轉接申請人。分機或需人工轉接時，可依入口提供的選項安排 Manual Callback；不要將自己的手機填成第三方已驗證的公司總機。
5. 完成回撥及其他驗證後，再依已購買的金鑰儲存方案領取或啟用憑證。

SSL.com 的 [OV 文件要求](https://www.ssl.com/faqs/ssl-ov-validation-requirements/)允許政府或可靠第三方資料網址，D‑U‑N‑S 可加速驗證；必要時仍會要求補件。[OV 回撥說明](https://www.ssl.com/how-to/callbacks-for-ov-certificates/)說明須驗證電話並成功聯繫。本案仍以訂單上實際收到的補件要求為準，公開說明不能保證三份整理件一定通過。證交所並未在已查閱的 SSL.com 範例清單中被明確列名，因此接受與否應由驗證團隊確認。

## 可直接貼給 SSL.com 的英文訊息

以下僅是待送出的草稿，尚未代使用者傳送。

> Hello Validation Team,
>
> I am applying on behalf of EMERGING DISPLAY TECHNOLOGIES CORP., a Taiwan-listed company (stock code 3038; Unified Business Number 89261652; Chinese registered name 全台晶像股份有限公司).
>
> I have prepared three evidence PDFs for your review. The legal-existence PDF includes the MOEA company registration API response and the unchanged seven-page English Articles of Incorporation published on our corporate website (last amendment listed: May 28, 2025). The address and contact PDFs include the TWSE company record. The covers and API extracts are applicant-prepared, not certified government documents or a D&B report.
>
> Government company profile and English-name linkage:
> https://findbiz.nat.gov.tw/fts/company/89261652?fhl=en
>
> TWSE listed-company basic information (please locate company code 3038 or Unified Business Number 89261652):
> https://openapi.twse.com.tw/v1/opendata/t187ap03_L
>
> The TWSE record dated October 10, 2026 lists our address as No. 5, Central 1st Rd., Qianzhen Dist., Kaohsiung, Taiwan, and our company switchboard as 07-8124832 (+886-7-8124832).
>
> Article 1 of the published English Articles uses Emerging Display Technologies Corporation, while our order and government import/export listing use EMERGING DISPLAY TECHNOLOGIES CORP. Please confirm the accepted certificate subject name and whether these sources satisfy the three validation categories. If you require an incorporation approval letter, certified Articles, a signed authorization, or a certified English translation, please specify the format. Please also advise on the callback procedure for a company switchboard with an extension.
>
> Thank you.

## 簽章操作的下一步

OV 驗證與簽章操作是不同步驟。SSL.com 的[簽章憑證流程](https://www.ssl.com/how-to/validation-process-for-document-signing-code-signing-and-ev-code-signing-certificates/)說明新簽發 Code Signing 私鑰須置於合規的硬體或雲端方案，不能沿用舊文章中下載 PFX 私鑰的操作。該頁也說明 2026 年單張 Code Signing 憑證的最長有效期為 458 天，購買多年方案不等於單張憑證可使用多年。驗證通過後再確認訂單採用 eSigner、硬體 Token 或自備 HSM 的哪一條路徑。

## 文件與來源

- `output/pdf/`：三份申請證據整理件及一份未簽署授權範本。
- `sources/moea-company-89261652.json`：經濟部即時 API 回應原始位元組。
- `sources/edt-articles-of-incorporation-en-original.pdf`：公司官網發布的 7 頁英文章程原始檔，最後列出的修訂日期為 2025-05-28。
- `sources/twse-listed-company-basic-information.json` 與 `.csv`：兩個官方來源下載的完整資料集；出表日期須以各自資料為準。
- `sources/twse-3038-record.json`：從官方 JSON 篩出的完整 3038 紀錄，未修改值。
- `sources/source-manifest.json`：官方下載網址、擷取日期及 SHA-256。
- `build_validation_pdfs.py`：PDF 生成程式；執行前需依 PDF 技能先標記一次 artifact operation。

文件於本機製作，已逐頁轉成圖片檢查；未登入 SSL.com、讀取實際訂單、上傳文件、聯絡驗證團隊、代簽或代表公司接受憑證協議。文件整理完成不代表憑證已核發。
