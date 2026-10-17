# MCU 共通架構與軟體堆疊

## 從熟悉的軟體世界出發

MCU 把處理器核心、記憶體介面與多種周邊整合在晶片中。許多 MCU 有內建 Flash 和 SRAM，也有依賴外部程式儲存的設計。你的程式通常需要更直接地負責初始化、時間安排和錯誤恢復。

| 已有軟體概念 | MCU 要補上的觀念 |
| --- | --- |
| 程式由作業系統啟動 | reset 後由啟動碼建立執行環境；也可能先經過 boot ROM 或 bootloader |
| 配置記憶體 | 必須知道 Flash、SRAM、stack、heap、DMA buffer 的位置和限制 |
| 呼叫 I/O API | API 背後是周邊狀態機、暫存器、接腳和電氣訊號 |
| thread 與非同步工作 | 另外有中斷與硬體自主執行；CPU 不是唯一進度來源 |
| timeout | 時脈、timer、排程延遲都影響事件何時真的發生 |
| log 和 exception | 加上暫存器、斷點、watchpoint、故障資訊與接腳波形 |

## 把一顆 MCU 拆成六個問題

| 層面 | 核心問題 | 換平台時通常要重查什麼 |
| --- | --- | --- |
| CPU 核心 | 指令如何執行，中斷如何進入 | 架構、例外模型、除錯功能，選配的 FPU 或 MPU |
| 記憶體與匯流排 | 指令和資料在哪裡，誰能存取 | 地址配置、容量、區段、DMA 可及性、cache |
| 時脈與重置 | 哪個模組有時脈，頻率如何產生 | oscillator、PLL、分頻、clock gate、reset reason |
| 周邊與接腳 | 如何把軟體動作變成外界訊號 | GPIO、pin mux、timer、ADC、UART、SPI、I2C |
| 執行與同步 | 誰在何時做事，資料由誰擁有 | polling、interrupt、DMA、RTOS 與同步規則 |
| 系統生命週期 | 如何啟動、故障、更新、休眠 | boot mode、watchdog、Flash 寫入、安全與低功耗 |

同一核心不保證相同周邊。同樣寫著 UART，也要查 FIFO、DMA、狀態旗標及錯誤處理。不同容量和封裝的 SKU 可能影響可用接腳；功能表上列出某周邊，也不代表它能與其他所需功能同時引出。

## 軟體堆疊各自解決什麼

由上往下追一個「送出資料」的動作，就能判斷 SDK 中的每個部分在做什麼。

| 組件 | 工作 | 學到什麼程度 |
| --- | --- | --- |
| 應用邏輯 | 取樣策略、狀態機、資料格式 | 自己設計與測試，盡量不依賴廠商型別 |
| middleware | 通訊協定、檔案系統、圖形等功能 | 有需求才選一種；先搞懂 buffer、生命週期與錯誤契約 |
| RTOS | task 排程與同步等執行服務 | 先能解釋為什麼需要多個 task，再加入 |
| HAL 或 driver | 操作晶片周邊 | 熟悉一家的用法，挑一條路徑追到底 |
| BSP | 板子的接線與板載元件設定 | 能找到 LED、按鈕、感測器與晶片接腳的對應 |
| 核心支援與啟動碼 | 中斷入口、核心存取、初始化 | 能追到 main，知道向量與 linker 如何配合 |
| 編譯與除錯工具 | 把程式放到正確位置並觀察執行 | 能讀 build log、map file 和 debugger 狀態 |

SDK 往往打包多個層次；IDE 是開發環境，並不是另一種執行層。實際專案也不一定按表格順序逐層呼叫。

CMSIS-Core 為 Cortex-M 的核心暫存器、例外及初始化提供共同介面與慣例。它有助於辨認共通部分，但不能推導所有廠商的 GPIO 或 UART API 相同。[Arm CMSIS-Core](https://arm-software.github.io/CMSIS_5/Core/html/)

Zephyr 用 devicetree 描述硬體與初始設定。學到這類平台時，把它對應回「硬體在哪裡、如何配置」，就能理解工具存在的原因。[Zephyr devicetree](https://docs.zephyrproject.org/latest/build/dts/index.html)

## 三條路徑要分開追

以定時採樣為例：控制路徑設定 timer 和 ADC；資料路徑把 ADC 結果搬到 buffer；通知路徑告知應用一批資料可處理。DMA 可以承擔搬運，中斷可以承擔通知，CPU 不必逐筆忙等。

任何新工具都先回答：它改變哪條路徑？誰擁有 buffer？完成代表已進入佇列、已搬完，還是外部訊號真的送完？這些問題比背函式名稱更能跨平台使用。
