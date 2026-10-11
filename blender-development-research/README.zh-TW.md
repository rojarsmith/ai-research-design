[English overview](README.md) | **繁體中文**

# Blender 從起步到商業製作成熟的研發歷程

研究日期：2026 年 10 月 11 日。

**Blender 的成長路徑，是先解決動畫工作室自己的製作問題，再把工具推向外部使用者；經歷公司倒閉與開源轉型後，透過影片製作、架構重整、專職開發與長期維護，逐步形成完整的 3D 製作工具。**它從 1994 年起步至今，累積了約 32 年的發展。早期可投入內部製作，與今天能支援多種商業流程，是不同程度的成熟。

本文回答三個問題：它最初怎麼做出來、後續如何跨過技術與組織瓶頸，以及什麼證據能支持「成熟到可以商業使用」。Blender 的定位是數位內容製作軟體，範圍包括建模、動畫、材質、渲染與合成；這裡的商業成熟度主要以動畫、影像與相關資產製作衡量。

延伸閱讀：[工程與製作流程](research/01-engineering-and-production.zh-TW.md)、[來源與證據判讀](research/02-sources-and-evidence.zh-TW.md)。

## 最早的起點是工作室的製作需求

Ton Roosendaal 在 1989 年成立荷蘭動畫工作室 NeoGeo。Blender 最初是工作室的內部工具，承接既有工具與經驗，包括 Amiga 上的光線追蹤程式。因此，「從 0」比較接近從一套自行設計的製作工具起步，背後已有動畫業務、使用者和圖形程式經驗。[官方歷史](https://www.blender.org/about/history/)

最初的重要需求，是面對客戶反覆修改時，讓製作人員能有效調整場景。它的介面從早期便允許把一個視窗分割成不同工作區。這反映出產品設計與實際工作緊密相連：工具必須讓製作者完成工作，而功能優先順序來自製作中的阻礙。[官方歷史](https://www.blender.org/about/history/)

依 Ton 的 25 週年回顧，1993 年已有設計，1993 年聖誕假期開始寫程式；1994 年 1 月 2 日已有可執行版本與視窗分割系統。第一批檔案建立後約 15 個月，Blender 才具備工作室內部製作所需的條件。1998 年 1 月 1 日，SGI 版本在網路公開提供。[創辦人回顧](https://www.blender.org/press/blenders-25th-birthday/)

**約 15 個月的里程碑指的是當年的內部工具，不是完成今天這種完整軟體的工期。**它也不能直接當作其他團隊重做 Blender 的時間估算。

## 關鍵發展時間軸

| 時間 | 事件 | 對成熟化的作用 |
| --- | --- | --- |
| 1993 至 1995 | 設計、第一個可執行版本、約 15 個月後投入內部製作 | 先建立能完成實際工作的核心。[創辦人回顧](https://www.blender.org/press/blenders-25th-birthday/) |
| 1998 至 2002 | 公開發行，成立 Not a Number，嘗試免費下載加付費功能等商業模式 | 從內部工具走向產品，也暴露營運與資金風險。[官方歷史](https://www.blender.org/about/history/) |
| 2002 | NaN 關閉；社群募資；10 月 13 日以 GNU GPL 開源 | 讓軟體在原公司退出後仍能持續發展。[歷史檔案](https://archive.blender.org/www/blenderorg/blender-foundation/history/index.html) |
| 2005 至 2008 | 製作 Elephants Dream，2007 年成立 Blender Institute，接著製作 Big Buck Bunny | 恢復開發者與藝術家共同工作的環境，以作品要求推進技術。[官方手冊歷史](https://docs.blender.org/manual/id/4.4/getting_started/about/history.html) |
| 2007 至 2011 | Blender 2.5 架構與介面重整，2.57 於 2011 年 4 月成為穩定版本 | 重寫事件與工具系統，建立更一致的資料存取、Python 擴充與動畫操作方式。[2.57 公告](https://www.blender.org/press/blender-257-release/) |
| 2011 至 2012 | 2.61 加入 Cycles；Tears of Steel 推動實拍特效流程 | 提升渲染能力，並補強追蹤、遮罩與影像合成。[2.61](https://archive.blender.org/www/development/release-logs/blender-261/index.html)、[開放製作專案](https://archive.blender.org/www/features-gallery/blender-open-projects/index.html) |
| 2019 | 7 月 30 日發布 2.80，整合新介面、EEVEE 等重大改變 | 改善創作操作與預覽；也需要使用者遷移既有腳本和工作方式。[發布公告](https://www.blender.org/press/blender-2-80-released/)、[版本內容](https://www.blender.org/download/releases/2-80/) |
| 2020 | 6 月 3 日發布第一個 LTS 版本 2.83 | 大型或長期專案能固定版本，同時獲得後續重要修正。[2.83 LTS](https://www.blender.org/download/releases/2-83/) |
| 2021 | 2.92 加入 Geometry Nodes；3.0 加入 Asset Browser 並更新 Cycles | 增加程序化製作、資產重用與渲染效率。[2.92 公告](https://www.blender.org/news/blender-2-92-release/)、[3.0](https://www.blender.org/download/releases/3-0/) |
| 2024 至 2025 | 使用 Blender 製作的長篇動畫 Flow 上映，2025 年獲奧斯卡最佳動畫長片 | 提供外部作品交付與品質認可的案例。[導演訪談](https://www.blender.org/user-stories/making-flow-an-interview-with-director-gints-zilbalodis/)、[學院得獎紀錄](https://www.oscars.org/oscars/ceremonies/2025) |
| 2026 | 7 月 14 日發布 5.2 LTS；截至查核時官方頁列出 9 月 15 日的 5.2.2 | 持續維護成熟產品；5.2 LTS 預定支援至 2028 年 7 月。[5.2 LTS](https://www.blender.org/releases/5-2/) |

## 開源轉型解決了存續問題

1998 年成立的 Not a Number（NaN）嘗試把 Blender 變成商業產品。官方歷史記載，其後雖獲得投資，仍因經濟環境、支出與投資人關係等問題，在 2002 年初關閉。這個案例說明，工具有使用者與技術價值，仍需要能持續運作的組織與資金。[官方歷史](https://www.blender.org/about/history/)

Blender Foundation 隨後推動 Free Blender 募資。歷史檔案記載，與投資人議定的開源條件為一次性 10 萬歐元，募資約七週達標，並在 2002 年 10 月 13 日以 GNU GPL 釋出。現行歷史頁記錄募得約 11 萬歐元；兩個數字分別描述門檻與募資結果。[歷史檔案](https://archive.blender.org/www/blenderorg/blender-foundation/history/index.html)、[現行歷史](https://www.blender.org/about/history/)

從發展機制看，開源使外部開發者能檢查、修改與延續軟體，降低原公司結束就讓工具消失的風險。不過，它只是打開協作與延續的條件；如何分工、處理缺陷和支付長期維護成本，仍要靠後續制度解決。

## 真實影片把功能變成可用的製作流程

開源初期，分散各地的貢獻者不容易維持原本工作室裡開發者與製作者每天互相回饋的方式。Foundation 因此組織藝術家與開發者一起完成影片，讓軟體接受完整製作流程的考驗。[歷史檔案](https://archive.blender.org/www/blenderorg/blender-foundation/history/index.html)

| 作品 | 製作推動的技術工作 |
| --- | --- |
| Elephants Dream，2006 | 角色動畫系統、渲染系統與節點式影像合成器。 |
| Big Buck Bunny，2008 | 毛髮編輯與渲染、卡通角色，以及草木等戶外場景。 |
| Sintel，2010 | 在 Blender 2.5 開發過程中製作，協助功能與品質收斂。 |
| Tears of Steel，2012 | 攝影機追蹤、攝影機解算、遮罩、寫實渲染與調色。 |

各片的技術目標見[當年的官方專案記錄](https://archive.blender.org/www/features-gallery/blender-open-projects/index.html)；Sintel 與重構、穩定化的關係見[2.57 公告](https://www.blender.org/press/blender-257-release/)。

這些專案的價值，是把「有一個功能」推進到「功能能和其他功能一起完成作品」。例如，動畫工具要和角色資料、場景、渲染及合成共同運作；單一功能的展示無法證明整個流程可交付。

製作資料也會公開，使其他人能學習、檢查與再利用工作流程。Blender Studio 現在持續提供影片資產及製作知識。由此可推論，作品既是技術驗證，也是培養使用者和傳播經驗的方式。[Elephants Dream 製作資料](https://orange.blender.org/download/)、[Studio Vault](https://studio.blender.org/vault/)

```mermaid
flowchart LR
    A[作品需要與交付期限] --> B[藝術家遇到流程瓶頸]
    B --> C[共同設計與開發]
    C --> D[在真實場景中測試]
    D --> E[修正並整合到版本]
    E --> F[更多使用者與回饋]
    F --> A
```

此圖是對上述製作與開發關係的整理，並非每個版本都必須經過影片專案。

## 成熟化需要多次重整底層

Blender 並沒有只靠持續增加工具來成長。2.5 專案起於 2007 年，重寫核心事件與工具系統；2.57 在 2011 年發布時，新 Python 環境讓外掛能更完整地融入軟體。Sintel 完成後，團隊集中處理大量缺陷，Foundation／Institute 也聘請四位開發者協助穩定化。[2.57 公告](https://www.blender.org/press/blender-257-release/)

2.80 則同時改變介面與場景處理方式。它提供工作區、預設左鍵選取、EEVEE 即時渲染與新的場景組織方式。底層 dependency graph（相依圖）負責在場景變動後，更新受影響的資料，讓動畫、修改器、視窗與渲染能取得正確結果。[2.80 版本內容](https://www.blender.org/download/releases/2-80/)、[相依圖設計](https://developer.blender.org/docs/features/core/depsgraph/)

這些改變有遷移成本：2.80 的 Python API 有不相容變更，既有外掛與腳本需要調整；Blender Internal 與 Blender Game Engine 等功能也被移除。這反映出成熟產品必須處理維護負擔與架構取捨。[2.80 相容性說明](https://www.blender.org/download/releases/2-80/)

渲染也經歷相似過程。Cycles 在 2.61 首次加入時，官方明確稱它為預覽版本，仍有製作功能待補。十年後，Cycles X 的開發者回顧指出，過去架構決策已限制效能與維護，因此再次重整。這是長期工程累積的重要部分。[2.61 公告](https://archive.blender.org/www/development/release-logs/blender-261/index.html)、[Cycles X](https://code.blender.org/2021/04/cycles-x/)

## 經費與分工讓開發可以持續

現今的 Development Fund 資助專職開發、技術維護與相關工作，公開名單涵蓋渲染、動畫、節點、介面、文件、缺陷分類與基礎設施。軟體能免費取得，背後仍需要有人長期支付這些工作。[基金說明](https://fund.blender.org/about/)、[資助名單](https://fund.blender.org/grants/)

2019 年，Epic Games 公告提供 120 萬美元、分三年交付的 MegaGrant，支援 Blender 的開發專業化。Ubisoft 同年宣布其動畫工作室將採用 Blender 並加入基金，描述先從短篇內容開始，再用於後續節目。這些是資助與採用的具體記錄；Ubisoft 當時的公告屬於計畫，不能直接視為所有後續節目均已完成轉換。[MegaGrant 公告](https://www.blender.org/press/epic-games-supports-blender-foundation-with-1-2-million-epic-megagrant/)、[Ubisoft 公告](https://news.ubisoft.com/en-us/article/1Fse1XyXzj76UJ1gKFohbz/ubisoft-joins-blender-development-fund-to-support-open-source-animation)

基金現行政策指出，捐款不取得專案方向的決策權；發展路線由貢獻者及開發、產品主管制定，並維持個人與企業捐款的平衡。這是治理制度的說明，不能單憑政策文字就斷言實務上完全沒有利益壓力。[Funding Policy](https://fund.blender.org/funding-policy/)

開發工作按模組組織，由負責人協調設計、程式碼審查、缺陷修正、測試與文件，藝術家和使用者也能參與。現行發行制度以每年三個穩定版本為目標，其中一個提供兩年 LTS；新功能開發和穩定化階段分開，LTS 修正則經品質檢查後回移。[模組制度](https://developer.blender.org/docs/handbook/organization/modules/)、[發行週期](https://developer.blender.org/docs/handbook/release_process/release_cycle/)

## 商業成熟有成果證據也有適用範圍

### 授權允許商業創作

依 Blender 官方授權說明，Blender 可用於商業創作，製作出的影像、影片與 `.blend` 資料不會因使用 Blender 就自動受到軟體 GPL 的相同要求。若另外使用素材、外掛或其他第三方內容，仍要依其各自授權處理；發行修改過的 Blender 或使用其 API 的外掛，也涉及不同條件。[授權說明](https://www.blender.org/about/license/)

### Flow 證明它能支援長篇作品

Flow 導演 Gints Zilbalodis 說，他在 2019 年主要因 EEVEE 轉用 Blender，希望攝影機、燈光與畫面風格能一起快速調整。這揭示了工具的實際優勢如何配合創作者的工作方式。[導演訪談](https://www.blender.org/user-stories/making-flow-an-interview-with-director-gints-zilbalodis/)

同一訪談也記錄了版本控管：動畫團隊在 2023 年開始後固定使用 3.3，後續燈光階段使用 3.6；每次更新前會測試檔案，過程中也有東西出問題。它說明成功製作需要團隊管理版本與處理缺陷。[訪談中的版本經驗](https://www.blender.org/user-stories/making-flow-an-interview-with-director-gints-zilbalodis/)

Flow 在 2025 年 3 月 2 日的第 97 屆奧斯卡獲最佳動畫長片，可由主辦學院的紀錄獨立核對。這支持「使用 Blender 的團隊能完成獲高度認可的長篇作品」，但獎項表揚的是作品，不能用來證明軟體全面優於其他工具。[學院得獎紀錄](https://www.oscars.org/oscars/ceremonies/2025)

### 大型製作仍需自己的整合與驗證

Blender Studio 公開的流程設計主要服務約 10 至 20 人的小型製作單位。這提供可參考的完整工作方法，但數百人的跨國製作還需要另行確認資料管理、權限、資產發布和工具整合。[Studio 設計原則](https://studio.blender.org/tools/pipeline-overview/design-principles)

格式互通也有邊界。例如 5.2 的 USD 手冊記錄，部分場景組合概念與材質節點仍有限制。因此，能匯入或匯出某種格式，並不代表所有場景資訊都能完整往返。[5.2 USD 手冊](https://docs.blender.org/manual/id/5.2/files/import_export/usd.html)

## 從 Blender 可以學到的研發方法

以下是對上述歷程的分析歸納，不是 Blender 官方保證的成功公式。

1. **先建立會被實際使用的核心。**早期工作室讓開發者能直接知道哪些功能影響交付。
2. **用完整作品檢驗整合。**把建模、動畫、渲染與合成接起來，才能暴露功能展示看不到的問題。
3. **在架構阻礙發展時投入重整。**2.5、2.80 和 Cycles X 都說明，成熟過程包括重新設計既有系統。
4. **把開發、測試與維護變成持續有人負責的工作。**社群擴大參與，經費與模組制度支撐長期責任。
5. **讓版本與資產管理跟上功能。**商業製作需要穩定交付，也需要能重用資產、固定環境與控制升級。

Blender 的歷程支持這樣的理解：成熟的創作軟體，是技術能力、真實製作回饋與長期維護共同累積的結果。它在很早期就能支援特定工作，後來才逐步擴大到今天的製作範圍。
