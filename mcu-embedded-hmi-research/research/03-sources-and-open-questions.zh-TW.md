# MCU HMI 官方來源與待確認事項

[回主報告](../README.zh-TW.md) · 查核日期：2026 年 10 月 12 日，Asia/Taipei。

官方網站與文件用來查核產品定位、規格、功能說明及公告。架構取捨與成本模型為工程推論；本輪未取得能在相同條件下比較八項方案的獨立效能數據，不把廠商的快速、低負載或高可靠性說法改寫成比較結論。

## 使用者指定入口

| 產品 | 原始入口 | 本輪讀取方式與範圍 |
| --- | --- | --- |
| SquareLine | [首頁](https://squareline.io/) | 文字擷取不完整；官方文件及瀏覽器價格頁補足 |
| TouchGFX | [UI Components](https://support.touchgfx.com/docs/category/ui-components) | 已讀取，包含分類與元件子頁 |
| DWIN | [原始帶參數連結](https://www.dwin.com.cn/DGUS.html?jskey=935515&jskey=959197&jskey=258066&jskey=785428&jskey=852838) | 文字擷取不可用；瀏覽器成功讀取 [DGUS 主頁](https://www.dwin.com.cn/DGUS.html)，網站自行附上 jskey |
| LVGL | [Widgets](https://lvgl.io/docs/open/widgets) | 已讀取，頁面標示 Open v9.6.0 |
| 華凌 | [CAN 智慧顯示器](https://www.winstar.com.tw/zh-tw/products/smart-display/can-display.html) | 已讀取系列說明與第 1 頁 SKU 表，未逐項核對全部產品手冊 |
| Levetop | [指定串口屏晶片分類](https://www.levetop.cn/tw/Product/list.aspx?lcid=131) | 文字擷取失敗；瀏覽器成功確認分類與 LT268B／LT269 產品內容 |
| ARTERY | [台灣首頁](https://www.arterychip.com/tw/index.jsp) | 已讀取，再查核 F437 規格與官方 LVGL 範例 |
| HMI Studio | [指定入口](https://hmistudio.io/) | 文字擷取失敗；瀏覽器成功讀取 [www 產品頁](https://www.hmistudio.io/) |

## 主要證據

| 編號 | 官方來源 | 支持的範圍與邊界 |
| --- | --- | --- |
| S01 | [SquareLine Overview](https://docs.squareline.io/docs/introduction/overview/) | Studio 建立在 LVGL 上的產品定位 |
| S02 | [SquareLine workflow](https://docs.squareline.io/docs/introduction/typical_dev/) | 模擬、專案／UI 匯出、C 檔案與驅動整合責任 |
| S03 | [SquareLine widgets](https://docs.squareline.io/docs/widgets/) | 編輯器代表元件；不是 LVGL 所有版本的完整涵蓋率 |
| S04 | [SquareLine changelog](https://docs.squareline.io/docs/miscellanos/changelog/) | 1.6.2、2026-08-10、LVGL 9.5、SVG、離線啟用 |
| S05 | [SquareLine pricing](https://squareline.io/pricing/licenses) | 瀏覽器確認 USD 定價、方案資格與限制；文字擷取的動態金額不可靠 |
| S06 | [TouchGFX 產品頁](https://www.st.com/en/development-tools/touchgfxdesigner.html) | 免費、STM32、程式產生、模擬與工具鏈定位 |
| S07 | [What is TouchGFX](https://support.touchgfx.com/docs/introduction/what-is-touchgfx) | Designer、Generator 與 C++ Engine |
| S08 | [TouchGFX UI Components](https://support.touchgfx.com/docs/category/ui-components) | 元件分類；本輪擷取版本選單曾顯示 4.26 |
| S09 | [TouchGFX Miscellaneous](https://support.touchgfx.com/docs/category/miscellaneous) | Graph、Gauge、Video 等代表元件及影片格式 |
| S10 | [DGUS 平台](https://www.dwin.com.cn/DGUS.html) | 瀏覽器確認圖片圖層、顯示／觸摸控件與功能描述 |
| S11 | [DWIN development guides](https://www.dwin-global.com/development-guide/) | 官方目前列 T5L_DGUSII V2.9 與其他產品文件；目錄不代替全文 |
| S12 | [DWIN video tutorials](https://www.dwin-global.com/t5l-dgus-v7-6-video-tutorial/) | 教程的文字、曲線、多語與進度條主題；未以影片標題推定全部機型支援 |
| S13 | [DWIN tools](https://www.dwin-global.com/tool-page/) | 列 DGUS_V7651 等工具；工具版號與核心版號分開 |
| S14 | [LVGL introduction](https://lvgl.io/docs/open/introduction) | C 框架、可移植定位與 Pro 區別 |
| S15 | [LVGL requirements](https://lvgl.io/docs/open/introduction/requirements) | 編譯器、OS、記憶體各項與 buffer 條件 |
| S16 | [LVGL license](https://lvgl.io/docs/open/introduction/license) | Open MIT 商用；Pro 為商業工具，第三方依賴另查 |
| S17 | [LVGL widgets](https://lvgl.io/docs/open/widgets) | v9.6.0 的元件清單；存在元件不代表任意硬體可流暢執行 |
| S18 | [華凌 CAN 系列](https://www.winstar.com.tw/zh-tw/products/smart-display/can-display.html) | CANopen／Custom CAN ID、DBC、STM32 平台及特定 SKU 資訊 |
| S19 | [Levetop 串口屏分類](https://www.levetop.cn/tw/Product/list.aspx?lcid=131) | 指定範圍的產品系列與相鄰 TFT 圖形控制器分類區別 |
| S20 | [LT268B／LT269](https://www.levetop.cn/tw/Product/info.aspx?itemid=592&lcid=131) | 瀏覽器讀取特定晶片的核心、記憶體、面板介面與顯示指令 |
| S21 | [Levetop UART TFT downloads](https://www.levetop.cn/en/Download/list.aspx?lcid=244&pid=244) | 依晶片列工具代別與手冊；較新下載項目不能自動套入舊晶片 |
| S22 | [AT32F437](https://www.arterychip.com/en/product/AT32F437.jsp) | 晶片資源、XMC、封裝限制，非完整 HMI 的效能基準 |
| S23 | [SC0118 LVGL FreeRTOS Demo](https://arterychip.com/download/Example%20Code/SC0118_LVGL_FreeRTOS_Demo_on_AT32_EN_V2.0.0.pdf) | 2023-05-04、F435／F437、XMC＋DMA；未由舊範例推定新 LVGL 的支援 |
| S24 | [HMI Studio 公開頁](https://www.hmistudio.io/) | 瀏覽器確認公開階段與工作流程；不構成量產效能或客戶採用證明 |

TouchGFX 個別頁面在本輪顯示的版本選單不一致：UI 分類為 4.26，另一次讀取 What is TouchGFX 顯示 4.27。因此本版不聲稱已鎖定最新套件版本；實機評測需記錄下載的確切版本。

DWIN V2.9 PDF 連結擷取逾時；Levetop UI_Editor-II 英文手冊超出擷取大小限制。這些文件的目錄可確認存在，但全文內容未用來支持新增規格或協定細節。相同文件的網路搜尋發布時間也未當成正式發布日；日期以文件內文或官方 changelog 為準。

## 採購與實機前需要回答的問題

| 方案 | 優先待確認資料 | 影響 |
| --- | --- | --- |
| SquareLine Studio | 精確 LVGL／BSP 相容矩陣、商用席次與到期權利、完整元件／匯出涵蓋率、版本管理方式 | 能否持續重建、升版及多人維護 |
| TouchGFX | 實際套件版本與授權、目標 STM32 的顯示／記憶體配置、AL／BSP 支援、外部資產配置 | 工具鏈可用性與整機資源 |
| DWIN DGUS | 精確模組及 T5L 核心版本、DGUSII 協定與觸摸回報、字型、多媒體與更新方式、商用條款 | 主控整合、維護與換型號成本 |
| LVGL Open | 目標 port、版本、輸入／display driver、RTOS 協作、字型與解碼器授權、資源量測 | 工程負擔、功能與移植 |
| 華凌 CAN | 指定 SKU、GUI Builder 元件及授權、DBC／CANopen 細節、BSP 原始碼、支援版本與 PCN | 正確選型、客製能力與供貨 |
| Levetop | 晶片與工具代別、協定／格式相容性、外部 Flash／面板配置、量產授權與燒錄、交期 | 硬體整合與跨代維護 |
| ARTERY AT32 | 精確料號／封裝、顯示及外部 RAM 方案、SDK／範例授權、LVGL 版本與工具支援、供貨 | 板級可行性與完整 BOM |
| HMI Studio | 目標硬體、執行環境、輸出格式、協定清單、商業授權、正式版狀態、版本遷移與部署復原 | Alpha 評估能否轉成可維護交付 |

需求端則需固定解析度、觸控方式、資料頻率、CAN／UART／Modbus 等介面、量產數量、開發團隊能力及所需原始碼權利。這些尚未指定時，維持情境式選型，不選出單一最佳產品。

## 後續研究記錄

每次更新新增查核日期、URL、文件內版本／日期、具體變動及受影響結論。取得實測時，附硬體、工具鏈、資產、工作負載、量測方法與原始記錄。取得報價時，另記數量、稅、有效期、服務與授權，才能與工程工時合併為總成本。
