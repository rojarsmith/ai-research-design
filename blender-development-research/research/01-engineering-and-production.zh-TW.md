[回到主報告](../README.zh-TW.md)

# Blender 工程架構與製作流程的成熟化

研究日期：2026 年 10 月 11 日。

若要從理解 Blender 進一步走向自行實作，可接著閱讀[工程架構](03-build-large-3d-software.zh-TW.md)、[C++ 學習路線](04-cpp-learning-roadmap.zh-TW.md)與[原始碼導讀](05-reading-blender-source.zh-TW.md)，並執行[小型核心範例](../examples/mini-editor-core/README.zh-TW.md)。

Blender 能支援長期製作，除了畫面生成能力，也依賴場景資料、工具操作、外掛、資產連結與版本維護能一起運作。以下依官方開發文件與 Studio 的製作記錄，說明這些機制如何支撐產品。

## 場景資料是各功能共同運作的基礎

Blender 的資料包含物件、網格、材質、動畫與它們之間的關係。官方程式碼導覽指出，儲存在 `.blend` 的主要結構定義位於 `makesdna`；許多屬性定義位於 `makesrna`，介面面板和選單則有不少由 Python 定義。[程式碼導覽](https://developer.blender.org/docs/handbook/new_developers/navigate_code/)

| 系統 | 工作 | 對製作的意義 |
| --- | --- | --- |
| DNA | 定義主要儲存資料結構 | 場景內容有明確的資料表示。 |
| RNA | 提供結構、屬性、函式與中繼資料描述 | 介面、動畫與 Python API 可以使用共同的資料描述。 |
| Operators | 把工具操作抽象成一致的呼叫方式 | 同一操作能由按鍵、選單、按鈕或腳本觸發。 |
| Dependency Graph | 追蹤資料相依關係，安排場景更新 | 改動物件或參數後，相關動畫、修改器與渲染資料得到更新。 |
| `.blend` 讀寫系統 | 載入及寫入場景檔案 | 讓製作內容可以保存、再開啟及交接。 |

表中功能依據：[DNA 定義位置](https://developer.blender.org/docs/handbook/new_developers/navigate_code/)、[RNA](https://developer.blender.org/docs/features/core/rna/)、[2.57 工具系統](https://archive.blender.org/www/development/release-logs/blender-257/index.html)、[相依圖](https://developer.blender.org/docs/features/core/depsgraph/)、[程式碼目錄](https://developer.blender.org/docs/features//code_layout/)。「對製作的意義」是工程分析。

例如，把角色移到另一個位置後，相關骨架、網格變形與畫面都需要更新。若各功能自行維護不同資料，整合就容易出錯。共同資料描述與相依更新機制，提供跨功能協作的基礎。

相依圖設計也區分原始資料與計算後的資料，讓修改器、限制條件等運算作用在評估用資料上，渲染引擎使用其結果。這是避免不同場景狀態或運算彼此干擾的重要設計。[相依圖設計](https://developer.blender.org/docs/features/core/depsgraph/)

## 高效能核心與 Python 擴充共同支撐工具

Blender 的程式碼目錄把資料核心、數學與工具函式、網格編輯、場景評估、視窗繪製、合成器和編輯工具分成不同區域。Cycles 又有自己的場景、路徑追蹤核心與硬體裝置層。這顯示它是多個專業系統的整合。[程式碼目錄](https://developer.blender.org/docs/features//code_layout/)、[Cycles 目錄](https://developer.blender.org/docs/features/cycles/source_layout/)

Python 擴充讓工作室能建立自訂操作、介面、匯入匯出及流程工具。2.57 的官方記錄說明，2.5 重新實作 Python API，並讓工具操作、資料與介面存取更加一致。[2.57 技術記錄](https://archive.blender.org/www/development/release-logs/blender-257/index.html)

以工程觀點看，這種分工使耗費運算的核心可集中處理效能，而流程客製化有較方便的介面。代價是 API 變動會影響外掛，所以專案要管理外掛與 Blender 的相容版本；2.80 的發布說明就明確記錄 API 不相容變更。[2.80](https://www.blender.org/download/releases/2-80/)

Blender 也採用其他開源元件。官方授權頁列舉 Python、Bullet、Libmv 和 OSL。自研內容因此包括整合與維護這些技術，並不代表每一個演算法和底層函式都重新發明。[元件授權說明](https://www.blender.org/about/license/)

## 渲染與程序化製作擴大了工作範圍

Cycles 的初期發布包含光線追蹤、節點式著色、互動渲染與 GPU 加速，但仍屬首個預覽版本。Cycles X 則是在十年經驗之後處理架構、效能與維護問題。不能把 2011 年「加入渲染器」理解成當時就已完成所有商業需求。[2.61](https://archive.blender.org/www/development/release-logs/blender-261/index.html)、[Cycles X](https://code.blender.org/2021/04/cycles-x/)

EEVEE 讓製作者能快速預覽並調整畫面。Flow 導演的訪談尤其強調，同時調整攝影機、燈光與畫面風格的速度；這種回饋時間可以直接影響創作方式。[導演訪談](https://www.blender.org/user-stories/making-flow-an-interview-with-director-gints-zilbalodis/)

Geometry Nodes 在 2.92 初期主要處理物件散布與實例，後續逐步擴大。Asset Browser 在 3.0 提供資產整理與重用。以製作流程來看，前者可把重複工作變成可調整的程序，後者讓已有內容更容易再次使用。[2.92](https://www.blender.org/news/blender-2-92-release/)、[3.0 資產瀏覽器](https://developer.blender.org/docs/release_notes/3.0/asset_browser/)

3.0 的發布頁宣稱部分真實場景 GPU 渲染比 2.93 快 2 至 8 倍；其展示條件包括 NVIDIA Quadro RTX A6000 與 OptiX。這是官方在特定條件下的結果，不是所有硬體、場景與設定的保證。[3.0 效能展示](https://www.blender.org/download/releases/3-0/)

## 團隊製作需要資產與環境管理

在多人專案中，模型、材質、骨架、動畫與燈光往往由不同人處理，還會跨鏡頭重用。Library Overrides 允許對連結資料作局部調整，再追蹤來源更新；但 Studio 的實務文章也指出，多層覆寫會增加複雜性與技術負擔。[Studio 製作經驗](https://studio.blender.org/blog/rigging-shaders/)

Studio 公開的工具包含 Asset Pipeline、Blender Kitsu、CloudRig 等，分別涉及資產流程、鏡頭與製作資料，以及角色綁定。Project Tools 則以標準目錄與共享環境，讓團隊使用相同 Blender 和外掛。[工具清單](https://studio.blender.org/tools/addons/overview)、[Project Tools](https://studio.blender.org/tools/user-guide/project_tools/project-overview)

這些記錄支持一個工程結論：商業製作的成熟度，有一部分來自 Blender 本體，也有一部分來自其周邊流程。公司導入時仍需安排資產命名、發布、備份、檔案路徑、版本固定與升級驗證。

官方 Studio 流程的設計對象為約 10 至 20 人的小型單位，且偏向使用 Blender 的連結系統。這是可重用的起點，不能直接推論它已完整涵蓋所有大型製片公司的需求。[設計原則](https://studio.blender.org/tools/pipeline-overview/design-principles)

## 品質制度把功能發布與長期維護接起來

官方模組制度要求負責人安排程式碼審查、缺陷修正、發布測試及文件。藝術家與使用者可作為測試者和需求參與者，與開發者一起檢查變更。[模組制度](https://developer.blender.org/docs/handbook/organization/modules/)

自動化方面，Blender 使用 GoogleTest 測試 C/C++ 程式，包含模組單元測試及需要跨模組的整合測試；BuildBot 提供建置與發布套件。這些是品質檢查工具，仍要配合實際場景與人工驗證。[C/C++ 測試](https://developer.blender.org/docs/handbook/testing/gtest/)、[BuildBot](https://developer.blender.org/docs/handbook/tooling/buildbot/)

現行發行流程區分新功能開發、Beta 缺陷修正與 Release Candidate；LTS 提供兩年重要修正。官方 FAQ 也說明，不成熟的功能可以順延，避免整套軟體必須等待所有工作同時完成。[發行週期](https://developer.blender.org/docs/handbook/release_process/release_cycle/)、[開發 FAQ](https://developer.blender.org/docs/handbook/new_developers/faq/)

## 可以借鏡但無法直接換算的投入

Blender 的可借鏡之處，是讓實際使用者持續參與、維持共同資料架構、允許流程擴充、用作品測試整合，並支付長期維護成本。開源增加了參與機會，組織與品質制度讓貢獻能持續累積。

這段歷程無法直接換算成另一個團隊需要多少人、多少年或多少預算。創辦人的 15 個月只對應初期內部工具；2024 年報所列開發者相關支出由約 177.7 萬增至 215.3 萬歐元，也只是該年度的組織資料，不能當作 Blender 三十多年總研發成本或重建報價。[創辦人回顧](https://www.blender.org/press/blenders-25th-birthday/)、[2024 年報財務頁](https://download.blender.org/foundation/Blender-Foundation-Annual-Report-2024.pdf)
