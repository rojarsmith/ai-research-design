# MCU HMI 八項產品的能力與開發流程

[回主報告](../README.zh-TW.md) · 查核日期：2026 年 10 月 12 日。

比較以使用者指定的產品系列為範圍。SquareLine 以 Studio 為主，不把首頁宣傳的 SquareLine Vision 視為相同授權產品；LVGL 以 Open 為主，商用 Pro 工具另外說明；Levetop 指定連結為 TFT 串口屏控制晶片，不能與其 TFT 圖形控制器系列混為一談。

## 平台與整合責任

| 方案 | 畫面執行位置與工具輸出 | 主控整合方式 | 主要責任與依賴 |
| --- | --- | --- | --- |
| SquareLine Studio | 匯出 LVGL UI C 原始碼及圖像、字型等資源，於目標韌體執行 | 在事件與應用程式間加入資料及控制程式 | 團隊提供 LVGL、顯示／輸入驅動、編譯環境與通訊 |
| TouchGFX | Designer 產生 C++ UI；Engine 在 STM32 執行 | 應用與 UI 模型、回呼及 STM32 韌體整合 | STM32CubeMX、Abstraction Layer、顯示與記憶體設定 |
| DWIN DGUS | 圖片與控件設定配合 DWIN 智慧屏執行環境 | T5L UART 資料交換；其他介面須看模組及開發模式 | DGUS 工具、核心韌體、顯示資源與特定智慧屏 |
| LVGL Open | C 圖形函式庫直接整合於自行編譯的韌體 | 自訂事件、資料模型與通訊程式 | 團隊管理渲染、記憶體、驅動與執行緒協作 |
| 華凌 CAN | 整合 STM32 顯示模組；GUI Builder 或客製韌體路線 | CANopen 物件字典，或 Custom CAN ID 的訊號綁定 | 模組 SKU、GUI Builder、CAN 規格與可取得的 BSP |
| Levetop | 專用 UART TFT 控制晶片，搭配對應 UI_Editor 工具 | 主 MCU 透過串口指令或對應工具的資料控制方式 | 晶片型號、工具代別、外部 Flash、顯示板設計 |
| ARTERY AT32 | MCU 平台；可自行整合 LVGL | 韌體處理周邊及通訊，再更新 UI | MCU 封裝、顯示介面、BSP 與採用的圖形函式庫 |
| HMI Studio | Design、Logic、Protocol 工作區；部署格式和完整目標清單待確認 | 公開展示包含 serial commands 與 Modbus | 工具及目標執行環境相容性，正式交付與授權條件 |

表格的產品定位依據：[SquareLine 工作流程](https://docs.squareline.io/docs/introduction/typical_dev/)、[TouchGFX 組成](https://support.touchgfx.com/docs/introduction/what-is-touchgfx)、[DGUS](https://www.dwin.com.cn/DGUS.html)、[DWIN T5L 文件目錄](https://www.dwin-global.com/development-guide/)、[LVGL 簡介](https://lvgl.io/docs/open/introduction)、[華凌 CAN](https://www.winstar.com.tw/zh-tw/products/smart-display/can-display.html)、[Levetop LT268B／LT269](https://www.levetop.cn/tw/Product/info.aspx?itemid=592&lcid=131)、[AT32 範例](https://arterychip.com/download/Example%20Code/SC0118_LVGL_FreeRTOS_Demo_on_AT32_EN_V2.0.0.pdf)、[HMI Studio](https://www.hmistudio.io/)。

## UI 元件與延伸方式

元件名稱、圖片資源及組合式容器的計數方式不同，元件數量不能直接當成能力排名。以下列的是官方文件或公開頁明示的代表能力。

| 方案 | 代表能力 | 延伸方式與能力邊界 |
| --- | --- | --- |
| SquareLine Studio | Button、Label、Image、Arc、Textarea、Keyboard、Slider、Switch、Chart、Tabview 等 | 可組合元件並加入程式；編輯器清單不等同所有 LVGL widgets |
| TouchGFX | 按鈕、圖片、容器、進度指示、形狀；Graph、Gauge、時鐘、Slider、Text Area、Video | 自訂 C++ 元件與容器；Video 文件指 Motion JPEG／AVI，不能推論任意影片格式 |
| DWIN DGUS | 官方頁宣稱 28 個顯示、15 個觸摸控件；教程包含圖示、曲線、文字輸入、多語、進度條 | 以圖片和控件設定建立畫面；頁面「3D 動畫」描述為基於圖片，不能當成即時 3D 引擎 |
| LVGL Open | Button、Chart、Table、Menu、Keyboard、Calendar、Scale、Canvas 等，另列 GIF、Lottie、3D Texture | 可從 C 層延伸；額外解碼、渲染資源與外部 3D 能力仍要按功能確認 |
| 華凌 CAN GUI Builder | 官方明示 GUI 元件與 CAN 資料綁定 | GUI Builder 的完整元件清單待確認；改用 LVGL／TouchGFX 的能力須分開評估 |
| Levetop LT269 | 圖片、GIF、文字、進度條、幾何圖形、QR code、音訊等 | 特定晶片指令能力；不能把此清單推廣到全部 LT 系列 |
| ARTERY AT32 | 不自行定義通用 UI 元件庫；官方有 LVGL 範例 | 可用元件由所選框架決定，效能由晶片和板級整合決定 |
| HMI Studio | 拖放 widgets、圖片資產、多語畫面；Logic 節點與 Protocol 變數表 | 公開頁未列完整 widget 清單；AI 宣示不等於已驗證元件覆蓋率 |

來源：[SquareLine widgets](https://docs.squareline.io/docs/widgets/)、[TouchGFX UI Components](https://support.touchgfx.com/docs/category/ui-components)、[TouchGFX 其他元件](https://support.touchgfx.com/docs/category/miscellaneous)、[DGUS 平台](https://www.dwin.com.cn/DGUS.html)、[DGUS 教程](https://www.dwin-global.com/t5l-dgus-v7-6-video-tutorial/)、[LVGL widgets](https://lvgl.io/docs/open/widgets)、[華凌 CAN](https://www.winstar.com.tw/zh-tw/products/smart-display/can-display.html)、[LT269](https://www.levetop.cn/tw/Product/info.aspx?itemid=592&lcid=131)、[HMI Studio](https://www.hmistudio.io/)。

## 八項方案的工程取捨

### SquareLine Studio

SquareLine Studio 是建立在 LVGL 上的商業視覺工具。官方工作流程將專案骨架與 UI 匯出分開；自行已有韌體專案時，可匯出 UI 檔案，但仍需撰寫驅動並管理建置。這表示設計師可以處理畫面與事件，韌體工程師仍需完成主控資料、周邊及排程整合。[工作流程](https://docs.squareline.io/docs/introduction/typical_dev/)。

官方 changelog 的 1.6.2 發布日為 2026 年 8 月 10 日，新增 LVGL 9.5、SVG widget 與離線授權啟用。LVGL 官方文件目前標示 Open v9.6.0，兩者的版本更新並非同步；不能因此直接認定 Studio 支援所有 9.6 功能。專案應固定 editor、LVGL、BSP、字型與資源格式。[SquareLine changelog](https://docs.squareline.io/docs/miscellanos/changelog/)、[LVGL 文件](https://lvgl.io/docs/open/widgets)。

工程判斷：適合有韌體能力、需要加速視覺編輯的團隊。跨 MCU 的彈性來自 LVGL 與驅動整合，並非工具免除所有移植工作。其價格頁也明示 SquareLine 與 LVGL 為獨立公司，不能視為同一家公司的官方套裝。[價格頁](https://squareline.io/pricing/licenses)。

### TouchGFX

TouchGFX 包含 Designer、STM32CubeMX 的 Generator 與 C++ Engine。ST 官方表示框架免費、針對 STM32 最佳化，支援模擬與程式產生，且產生程式與使用者程式分開。這些是具體工具鏈能力；其「最低 CPU 與記憶體負擔」等宣傳仍須在共同畫面與硬體下測試。[產品頁](https://www.st.com/en/development-tools/touchgfxdesigner.html)、[套件組成](https://support.touchgfx.com/docs/introduction/what-is-touchgfx)。

工程判斷：已採 STM32 時值得優先建立基準，也應與相同 STM32 上的 LVGL 比較。無程式碼排版不代表不需要 C++、顯示初始化、記憶體配置或通訊程式。若將來改用 AT32 或其他品牌，不能預設取得相同官方工具鏈與授權適用範圍。

### DWIN DGUS

DGUS 官方介紹以 JPEG 圖片圖層搭配顯示與觸摸控件設定 UI。T5L 開發文件目錄另外列 UART、OS 與其他產品路線，顯示 GUI 製作與主控程式是不同工作。DGUS 的控件設定流程也不能與 TA instruction set 混為同一開發模式。[DGUS](https://www.dwin.com.cn/DGUS.html)、[文件目錄](https://www.dwin-global.com/development-guide/)。

工程判斷：適合用智慧屏承擔顯示工作、保留既有主控的架構。要評估資料更新頻率、觸摸回報、資源下載及維護流程。外觀能自由設計不等於版面、控件與核心都能如通用 C 框架般修改；通訊及多媒體能力須確認特定模組與韌體。

### LVGL Open

LVGL Open 是可整合到不同環境的 C 圖形函式庫，官方要求包含 C99 或更新編譯器，並可用於 bare metal 或 RTOS。Open 採 MIT 授權，可用於商業產品；LVGL Pro UI 工具是另行授權的商業產品，不能把 Pro 功能算進免費 Open 的開發工具成本。[簡介](https://lvgl.io/docs/open/introduction)、[需求](https://lvgl.io/docs/open/introduction/requirements)、[授權](https://lvgl.io/docs/open/introduction/license)。

工程判斷：適合把 UI 當作韌體核心能力、需要客製與跨平台的團隊。原始碼可取得有利於診斷及長期控制，但仍需持續管理 API 升版、板級驅動、資源與效能；免費函式庫不等於零整合成本。

### 華凌 CAN 智慧顯示器

官方系列頁區分 CANopen 與 Custom CAN ID：前者提供預綁 GUI 的物件字典，後者允許自訂 CAN ID、資料框架及 DBC 匯入。頁面列 CAN 2.0A/B；不應延伸為 CAN FD 支援。[CAN 系列](https://www.winstar.com.tw/zh-tw/products/smart-display/can-display.html)。

目前列表的一個具體例子是 WL0F00043000WGAAASA00：4.3 吋、480×272、STM32F750、16 MB Flash、5 V、CANopen。鄰近型號有 Custom CAN ID、12 V 與 GPIO 差異，不能把所有功能視為一個 SKU 同時具備。[型號表](https://www.winstar.com.tw/zh-tw/products/smart-display/can-display.html)。

工程判斷：適合需要整合模組與 CAN 變數綁定的設備。GUI Builder 路線與客製 LVGL／TouchGFX 韌體路線應分別估工；支援框架不等於 GUI Builder 專案可直接轉成另一框架，轉換能力與 BSP 交付待確認。

### Levetop 串口屏控制晶片

指定分類包含 LT168、LT268、LT269、LT7689、LT776 等。LT268B／LT269 頁面描述 Cortex-M4、最高 150 MHz、508 KB Flash、256 KB SRAM，透過 UART 接主控並驅動 SPI 或 8 位元 MCU 介面的面板；其小尺寸定位不能套用到全部系列。[產品分類](https://www.levetop.cn/tw/Product/list.aspx?lcid=131)、[LT268B／LT269](https://www.levetop.cn/tw/Product/info.aspx?itemid=592&lcid=131)。

官方下載目錄列出多代 UI_Editor、UI_Editor-II、UI_Editor-III 與 Lite，並按不同晶片提供資料。因此購買前要先固定晶片、工具、韌體、資源格式與協定。下載目錄中的 LT7589、LT779 等較新項目也值得後續評估，但不能只憑目錄推定與舊產品專案相容。[下載目錄](https://www.levetop.cn/en/Download/list.aspx?lcid=244&pid=244)。

工程判斷：相較採購整片智慧屏，晶片方案提供較大的硬體設計自由，也增加面板、Flash、電源、觸控與 EMC 整合責任。內含 MCU 不表示它等同一個可任意置換圖形框架的通用 MCU。

### ARTERY AT32

ARTERY 提供 MCU 平台，官方 SC0118 示範在 AT32F435／F437 上用 FreeRTOS 與 LVGL，透過 XMC 加 DMA 驅動 LCD。文件日期是 2023 年 5 月 4 日，證明已有整合路徑，不能證明目前所有 AT32 或 LVGL 9.6 均已驗證。[SC0118](https://arterychip.com/download/Example%20Code/SC0118_LVGL_FreeRTOS_Demo_on_AT32_EN_V2.0.0.pdf)。

AT32F437 官方列最高 288 MHz、最高 4032 KB Flash、512 KB SRAM，XMC 支援 LCD 8080／6800 模式；資源及腳位依型號、封裝而異，LQFP64 的 XMC LCD 有 8 位元限制。DVP 是影像輸入介面，不能直接當作 RGB LCD 輸出。[F437 規格](https://www.arterychip.com/en/product/AT32F437.jsp)。

工程判斷：適合自行設計硬體並掌握 BSP 的路線。AT32 的價格、可替代料、供貨及與既有韌體的相容性需具體料號評估；只有主頻或廠商「高性價比」敘述不足以判斷 HMI 效能。

### HMI Studio

公開頁提供 Design、Logic 與 Protocol 工作區；展示節點式邏輯、控制器變數表，以及透過 serial commands／Modbus 執行的案例。AI 部分宣稱可從描述或圖片建 UI，採 OpenRouter 或本機 Ollama，並提供單次撤銷及編輯規則檢查。這些是廠商展示，未作共同任務的成功率與成本驗證。[公開產品頁](https://www.hmistudio.io/)。

頁面標示 0.8.5 Alpha、2026 年 9 月 10 日發布、Windows 10／11 64-bit，僅供重要利害關係人評估且不得再散布。10 月 Beta 與 12 月 general release 是路線圖；截至本次頁面查核，不應改寫為已正式推出。

工程判斷：其差異化評估應放在畫面、邏輯與協定的完整工作流程。需要驗證目標 MCU、執行環境、輸出格式、所有支援協定與商業授權。公開頁不足以確認 LVGL C 匯出或通用 MCU 支援，因此本版不以既有內部專案資訊補成公開能力，也不給予品牌特例。

## 授權與成本比較

以下價格為研究日官方頁面資訊，USD；SquareLine 一般方案按開發者授權。不含硬體、稅、服務與整合工時。免費下載與商業量產權利應分別查核。

| 方案 | 公開條件或價格 | 選型時仍要計入 |
| --- | --- | --- |
| SquareLine Personal | 免費、不可商用；最多 10 screens、150 widgets、1 component | 不能用 Personal 代替商業授權 |
| SquareLine Small Business | 790／年；公司年收入加 funding 小於 150,000；最多 5 components | 公司資格、團隊席次、續約 |
| SquareLine Business | 220／月或 2,200／年；頁面另列 lifetime 4,200、floating 5,900，標示無 royalties | lifetime 含一年版本追蹤，額外一年追蹤標示 1,490；依實際 EULA 確認 |
| TouchGFX | ST 描述為免費圖形框架 | 套件授權、STM32 硬體、IDE 與 BSP 工時 |
| LVGL Open | MIT，可商用 | 保留 MIT 聲明及第三方資源授權；視覺工具、支援另計 |
| DWIN DGUS | 官方有工具下載，本版未建立商用條款與定價 | 指定智慧屏、維護工具、供貨與客製支援 |
| 華凌 CAN | 型號定價與 GUI Builder 授權待報價／條款確認 | 模組、CAN 整合、BSP、韌體客製與長期供貨 |
| Levetop | 工具可下載；晶片價格與工具／韌體商用條件待確認 | 晶片、Flash、面板、PCB、觸控與測試 |
| ARTERY AT32 | 指定料號價格待詢價；LVGL 授權另行適用 | MCU、顯示硬體、SDK／範例授權與工程人力 |
| HMI Studio | 公開為免費 Alpha 評估；未建立正式商業定價 | 商業權利、執行環境、維護及雲端 AI 使用量；本機 AI 需硬體資源 |

價格表由瀏覽器讀取 [SquareLine 官方價格頁](https://squareline.io/pricing/licenses)，避免將文字擷取中的 `$undefined` 或約當月費當成有效售價。該頁部分 FAQ 與價格表用語未完全一致，購買前以實際訂單及授權條款核對。[TouchGFX](https://www.st.com/en/development-tools/touchgfxdesigner.html)、[LVGL 授權](https://lvgl.io/docs/open/introduction/license)、[HMI Studio](https://www.hmistudio.io/)。

## 可據以決策的差異

1. **自行整合或採用智慧屏。** LVGL／TouchGFX 讓團隊管理渲染與韌體；DWIN／Levetop 將顯示工作集中於專用執行環境；華凌提供整合模組。HMI Studio 的硬體與執行環境邊界需補齊資料。
2. **畫面設計或完整應用流程。** SquareLine 解決 UI 編輯與匯出；HMI Studio 強調視覺、邏輯及協定協作。是否真的節省整機開發時間，取決於控制邏輯與通訊的實作成本。
3. **可移植的程式與可移植的專案。** C 原始碼能搬移不表示 editor 專案互通；智慧屏協定相近也不表示資源檔可以通用。移轉應比較實際工作清單。
4. **供應與維護。** 框架版本、工具授權、BSP、晶片料號、面板及資源檔都應留有可重建版本。模組縮短板級整合，但仍有 SKU、交期與變更通知需求。

目前無共同條件的 FPS、穩定性、開發工時或總成本數據，因此不給綜合分數。可依[共同評測方法](02-architecture-and-evaluation.zh-TW.md)把上述架構差異轉成實測資料。
