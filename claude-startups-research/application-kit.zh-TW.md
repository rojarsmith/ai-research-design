# Claude Startups 申請準備與英文草稿

查核日期：2026 年 10 月 12 日。[返回主報告](README.zh-TW.md)。

對本案，優先使用資格詢問稿；產品介紹留待官方確認申請路徑後使用。以下內容是可編輯草稿，不是已提交的申請或已寄出的訊息。中括號內容需用真實資料補齊。

## 優先向官方詢問資格

建議由有公司授權的聯絡人，在自己的 Claude／Console 帳號內 **Get help** 建立一個問題，請支援轉交適合的 Startups 或商務團隊。若資格不適用，可詢問一般 API 試用／企業合作；這不代表官方一定提供企業額度或例外。[官方支援流程](https://support.claude.com/en/articles/9015913-how-to-get-support)。

**Subject: Eligibility clarification for EDT HMI Studio, a new product within an established company**

> Hello Claude Startups team,
>
> I work at Emerging Display Technologies Corp. (EDT) on EDT HMI Studio, a product we are preparing to commercialize. EDT was established in 1994; HMI Studio is a new product within the company, rather than a separate startup whose incorporation date is the product launch date.
>
> Product website: https://www.hmistudio.io/
>
> HMI Studio helps embedded-device teams build human-machine interfaces using a visual editor and an AI assistant. The public release is currently an alpha. Its cloud assistant uses Claude models through OpenRouter, with a local Ollama option. We are assessing first-party Claude API experiments for image understanding and tool-driven editing.
>
> Could you clarify whether a new commercial product within an established company can qualify for the current Claude Startups program? If the funding route could apply, what types of funding qualify, and how is the applicant entity evaluated? We can provide the relevant entity and funding details if needed.
>
> Please also advise which benefits are currently available to newly accepted applicants. If this project is outside the program's scope, would an API pilot or another business engagement route be more appropriate?
>
> Thank you,
> [Name]
> [Actual role], EDT
> [Company email]

只有在正式公司聯絡身分及細節確認後，才加入以下補充問題：

> EDT has international operations, including a production location in Dongguan, China. The proposed Claude use would be by [actual entity and team locations], serving [actual markets]. Please clarify how the program's operating-location conditions apply to this structure and intended use.

個人的訂閱可以另在本人支援對話補充：

> Separately, I have an active Claude Max 20x subscription. I would like to confirm how to link its monthly API credits to the appropriate Console organization for authorized product experiments. This is separate from the startup eligibility question.

## 產品簡介草稿

此段只陳述產品功能與預計評測；**不能替代公司資格說明**。若表單有字數限制再縮短；目前未查到登入後的實際欄位與上限。

> EDT HMI Studio is an AI-assisted visual authoring tool for embedded human-machine interfaces. It helps device teams create screens, interaction logic and controller bindings without manually authoring the entire interface. The assistant can interpret descriptions or reference images and operate the editor through its existing actions, with validation and a reversible editing workflow. The tool also supports LVGL C code generation.
>
> Our public product is currently an alpha, with demonstrations and a Windows evaluation build at https://www.hmistudio.io/. The cloud assistant currently uses Claude through OpenRouter; local models are also supported through Ollama. We are evaluating a direct Claude API integration for image-to-screen tasks, tool-call reliability and multilingual interface editing. Any requested resources would support documented experiments and user validation, with human control over deployment to hardware.
>
> The product is being developed within EDT. Applicant entity, founding date, ownership and funding details will be provided accurately; the product's release date will not be represented as a company incorporation date.

若直連 API 並非公司實際打算，刪除相關句子，直接寫現有需求；不要為申請虛構路線圖。

## 送件資料表

這是研究建議的準備表，**不是官方必填表單**。不需要把未要求的私人文件全部上傳。

| 資料 | 本案目前內容 | 提交前需確認 |
| --- | --- | --- |
| 公司法律名稱 | Emerging Display Technologies Corp.，公開網站指向 EDT | 真正申請法人與登記名稱 |
| 產品名 | EDT HMI Studio | 對外名稱是否統一 |
| 產品網站 | https://www.hmistudio.io/ | 公開版本、階段、公司關係 |
| 公司成立時間 | 公開沿革為 1994 年 | 實際申請法人的登記日期 |
| 近期資金 | 未確認 | 最近兩年事件、種類、日期、收款主體及官方是否認可 |
| 聯絡信箱 | 網站顯示公司網域 `edt.com.tw` | 使用者可使用且獲授權的聯繫信箱 |
| 代表身分 | 使用者是 EDT 員工 | 公司是否授權代表提交及接受條款 |
| 產品階段 | 公開網站為 0.8.5 Alpha；本機為 0.9.0-dev | 實際最新可對外評估版本 |
| 商業模式 | 將商業化；具體方式未確認 | 軟體／硬體／服務收入；既有收入與目標分開 |
| 客戶與試用 | 未提供可核對數據 | 真實試用人數、日期、可公開的回饋 |
| Claude 用法 | 產品 OpenRouter provider；個人 Max 20x | 公司 Console 用量、是否有直連計畫 |
| 地區 | 台灣公司；集團有國際營運 | 實際 AI 使用人員、法人、控制關係與服務市場 |
| Console 組織 | 未讀取使用者帳號 | 正確組織與管理權限；福利／月額度歸屬 |

## 完整送件與後續查核

1. 取得公司授權，保留官方對本案資格的答覆。
2. 修正提供給審核者的產品資料矛盾，準備簡短展示及真實試用證據。
3. 登入[官方申請入口](https://platform.claude.com/offers/startups-application)，確認組織後按當時欄位填寫。
4. 公司成立、funding、員工／團隊人數、收入依真實情況填；沒有就寫沒有，不借用母公司歷史來冒充新創成績。
5. 留下提交副本與日期。若官方要求補件，按要求提供。
6. 核准後逐項檢查實際 portal 權益與 Billing；不能只依核准郵件推定每項福利已入帳。

不要先取消 Max、購買 Team 或額外註冊多個公司帳號來期待福利。任何方案變更應建立在實際可領取項目與使用需求上。
