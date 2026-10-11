[回到主報告](../README.zh-TW.md)

# Blender 研發歷程的來源與證據判讀

查核日期：2026 年 10 月 11 日。

## 來源使用原則

歷史事件以 Blender 官方歷史、創辦人回顧和當年的發布記錄為主；技術機制依開發文件與版本說明；商業製作依具名製作者的經驗。Flow 的獎項另以主辦學院的紀錄核對。

官方文件能支持功能、發布及制度的存在，不能單獨證明它全面優於其他工具。工作室和企業的說法保留為其採用經驗或計畫；因果關係與可借鏡方法由報告明示為分析。本文沒有進行軟體效能實測或完整原始碼審計。

本次網頁工具對部分 Blender 頁面的直接開啟回傳存取錯誤，內容主要透過搜尋服務返回的頁面正文與特定段落取得。以下保留原始頁面連結，不把搜尋摘要當作完整文件或財務審計。

## 歷史與版本來源

| 編號 | 來源 | 支持的範圍 |
| --- | --- | --- |
| H01 | [Blender History](https://www.blender.org/about/history/) | NeoGeo、既有工具、NaN、倒閉與開源轉型。屬官方回顧。 |
| H02 | [Blender 25th Birthday](https://www.blender.org/press/blenders-25th-birthday/) | Ton 於 2019 年回顧 1993 年設計、1994 年起步、15 個月內部製作，以及 1998 年公開 SGI 版本。 |
| H03 | [Historical Foundation History](https://archive.blender.org/www/blenderorg/blender-foundation/history/index.html) | Free Blender 的 10 萬歐元門檻、七週達標、2002 年 10 月 13 日開源，以及影片專案的起因。 |
| H04 | [Official Manual History](https://docs.blender.org/manual/id/4.4/getting_started/about/history.html) | 2007 年成立 Institute、開放電影與製作資料。 |
| H05 | [Open Projects Archive](https://archive.blender.org/www/features-gallery/blender-open-projects/index.html) | 早期各影片的技術目標與製作經過。 |
| V01 | [Blender 2.57 Announcement](https://www.blender.org/press/blender-257-release/) | 2.5 重構、Sintel、2011 年穩定版本與聘用開發者修正缺陷。 |
| V02 | [Blender 2.57 Technical Log](https://archive.blender.org/www/development/release-logs/blender-257/index.html) | 工具、資料存取、介面及 Python 系統。 |
| V03 | [Blender 2.61](https://archive.blender.org/www/development/release-logs/blender-261/index.html) | 2011 年 12 月 14 日發布；Cycles 首個預覽版本。 |
| V04 | [Blender 2.80](https://www.blender.org/download/releases/2-80/) | 介面、EEVEE、API 遷移、移除功能，以及 2.8 的資助情形。 |
| V05 | [Blender 2.80 Announcement](https://www.blender.org/press/blender-2-80-released/) | 2019 年 7 月 30 日的發布日期。 |
| V06 | [Blender 2.83 LTS](https://www.blender.org/download/releases/2-83/) | 2020 年 6 月 3 日的首個 LTS 版本，兩年重要修正。 |
| V07 | [Blender 2.92 Announcement](https://www.blender.org/news/blender-2-92-release/) | 2021 年 2 月 25 日發布，Geometry Nodes 初始範圍。 |
| V08 | [Blender 3.0](https://www.blender.org/download/releases/3-0/) | 2021 年 12 月 3 日發布，資產、節點與特定硬體下的渲染效能展示。 |
| V09 | [Blender 5.2 LTS](https://www.blender.org/releases/5-2/) | 2026 年 7 月 14 日發布；頁面列出的 5.2.2 與支援期限。 |
| V10 | [Release Archive](https://www.blender.org/releases/) | 版本狀態；查核時 5.3 列為 Beta，預期 2026 年 11 月，不能視為已正式發布。 |

## 工程與品質來源

| 編號 | 來源 | 支持的範圍 |
| --- | --- | --- |
| E01 | [Navigating the Code](https://developer.blender.org/docs/handbook/new_developers/navigate_code/) | DNA、RNA、工具與 Python 介面程式的位置。 |
| E02 | [RNA](https://developer.blender.org/docs/features/core/rna/) | 結構及屬性描述如何連接介面、動畫、覆寫與 API。 |
| E03 | [Dependency Graph](https://developer.blender.org/docs/features/core/depsgraph/) | 場景相依更新、原始與評估資料的分離；包含 2.8 的設計說明。 |
| E04 | [Code Layout](https://developer.blender.org/docs/features//code_layout/) | 核心、讀寫、網格、合成、視窗繪製與編輯工具的職責。 |
| E05 | [Cycles Source Layout](https://developer.blender.org/docs/features/cycles/source_layout/) | 渲染器與裝置層的模組分工。 |
| E06 | [Cycles X](https://code.blender.org/2021/04/cycles-x/) | 2021 年開發者對架構與維護瓶頸的回顧。 |
| E07 | [Asset Browser 3.0](https://developer.blender.org/docs/release_notes/3.0/asset_browser/) | 資產瀏覽器的初始支援與重用方式。 |
| E08 | [Modules](https://developer.blender.org/docs/handbook/organization/modules/) | 模組負責人、貢獻者、藝術家和使用者的責任。 |
| E09 | [Release Cycle](https://developer.blender.org/docs/handbook/release_process/release_cycle/) | 現行發行目標、穩定化階段及 LTS。 |
| E10 | [C/C++ Tests](https://developer.blender.org/docs/handbook/testing/gtest/) | GoogleTest、單元與整合測試。 |
| E11 | [BuildBot](https://developer.blender.org/docs/handbook/tooling/buildbot/) | 建置與發布套件的工具。 |
| E12 | [Developer FAQ](https://developer.blender.org/docs/handbook/new_developers/faq/) | 固定週期發布及不成熟功能順延的理由。 |
| E13 | [USD Manual 5.2](https://docs.blender.org/manual/id/5.2/files/import_export/usd.html) | 特定版本的格式互通與限制。不要把舊手冊限制直接套到新版。 |

## 製作與資金來源

| 編號 | 來源 | 支持的範圍 |
| --- | --- | --- |
| P01 | [Elephants Dream Downloads](https://orange.blender.org/download/) | 公開影片及製作資料。 |
| P02 | [Studio Vault](https://studio.blender.org/vault/) | 持續保存與分享製作資料。 |
| P03 | [Making Flow](https://www.blender.org/user-stories/making-flow-an-interview-with-director-gints-zilbalodis/) | 導演的轉用原因、版本固定、升級測試與製作取捨。 |
| P04 | [Academy 2025 Awards](https://www.oscars.org/oscars/ceremonies/2025) | Flow 的最佳動畫長片獎；不能單靠此頁證明使用何種軟體。 |
| P05 | [Studio Design Principles](https://studio.blender.org/tools/pipeline-overview/design-principles) | 約 10 至 20 人製作單位，以及製作需求回饋開發的原則。 |
| P06 | [Rigging Shaders](https://studio.blender.org/blog/rigging-shaders/) | 連結與 Library Overrides 的用途及複雜性。 |
| P07 | [Studio Add-ons](https://studio.blender.org/tools/addons/overview) | 資產、製作追蹤與角色工具的具體分工。 |
| P08 | [Project Tools](https://studio.blender.org/tools/user-guide/project_tools/project-overview) | 目錄與 Blender／外掛環境標準化。 |
| F01 | [Development Fund About](https://fund.blender.org/about/) | 專職開發與透明度安排。 |
| F02 | [Grants](https://fund.blender.org/grants/) | 受資助的開發、文件、缺陷與基礎設施工作；名單會變動。 |
| F03 | [Funding Policy](https://fund.blender.org/funding-policy/) | 捐款不取得方向決策權的現行政策。 |
| F04 | [Epic MegaGrant Announcement](https://www.blender.org/press/epic-games-supports-blender-foundation-with-1-2-million-epic-megagrant/) | 2019 年公布 120 萬美元，分三年交付。 |
| F05 | [Ubisoft Adoption Announcement](https://news.ubisoft.com/en-us/article/1Fse1XyXzj76UJ1gKFohbz/ubisoft-joins-blender-development-fund-to-support-open-source-animation) | 2019 年動畫工作室的採用計畫與企業資助。 |
| F06 | [Foundation Annual Report 2024](https://download.blender.org/foundation/Blender-Foundation-Annual-Report-2024.pdf) | 財務段落第 74 頁所列開發者相關支出；不是全部歷史成本。 |
| F07 | [Foundation Annual Report 2025 Announcement](https://www.blender.org/news/blender-foundation-annual-report-2025/) | 公告日期 2026 年 9 月 23 日。本報告只確認公告存在，沒有引用其財務數字。 |
| L01 | [Blender License](https://www.blender.org/about/license/) | 商業創作、輸出作品、外掛及其他元件的授權區分。 |

## 容易混淆的日期與數字

- **1994、1995 與版本 1.0。**生日回顧把 1994 年 1 月 2 日定為第一個可執行版本，並說約 15 個月後可內部製作；現行歷史頁另外記載 1995 年 1 月的 1.0。報告依事件描述，不把首次程式、版本命名與製作就緒混成同一天。
- **10 萬與 11 萬歐元。**舊官方檔案記錄開源條件與募資目標 10 萬；現行頁面記錄募得約 11 萬。它們不是今天的研發預算。
- **2002 年基金會成立月份。**現行歷史和英文歷史檔案記五月，部分舊版翻譯手冊記三月。主報告只使用不受此差異影響的年度與已核對的開源日期。
- **2024 年影片與 2025 年獎項。**Flow 的上映年度和得獎年度不同；奧斯卡典禮日期為洛杉磯當地 2025 年 3 月 2 日。
- **訪談日期與後來更新。**Making Flow 頁面標示 2025 年 1 月 22 日，但開頭已有後來的獎項資訊。主報告將製作經驗歸於訪談，將奧斯卡日期歸於學院記錄。
- **2025 年報與 2026 年公告。**2025 年報的公告發生在 2026 年；年報涵蓋年度不等於發布日期。

## 結論的適用範圍

有直接證據支持 Blender 已能支援商業影像製作，也有制度和工具支持長期維護。把 2019 年 2.80 視為採用的重要轉折，是根據版本變更、企業採用說明及製作者經驗的分析，而不是唯一的「商業可用起始日」。

本次未建立產業市占率、各工具的全面效能排行、數百人工作室的普遍導入成效或三十多年總研發成本。這些需要不同範圍的資料，不能由官方功能清單、單一獎項或年度財務數字推算。
