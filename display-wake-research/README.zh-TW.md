# 桌機雙螢幕長時間離席後無法自行喚醒

查核日期：**2026-10-14**。已納入使用者補充的 Acer ET322QK、ASUS VG289 與 Philips FTV；Windows 實際電源狀態、驅動版本、ASUS 後綴與 Philips 完整機型仍未知，因此不把候選原因寫成已確認根因。

最新成果：[型號與網路證據完整研究](research/01-online-findings.zh-TW.md) · [20 項第一方來源與適用界線](research/02-sources.zh-TW.md) · [喚醒觀察範本](cases/observation-template.md)。本次是公開資料研究，未更改問題電腦設定或執行喚醒測試。

## 納入型號後的優先方向

1. **先確認 Win+P 的使用模式。** Philips 也接著顯卡 HDMI；回到桌面時應確認 Acer/ASUS 都啟用。用拔除 Philips HDMI 的對照隔離第三台設備與切換配置。
2. **Acer 查 Auto Source 與 Quick Start Mode。** 固定 Input/關閉自動搜尋與開啟 Quick Start 分開比較；後者手冊只承諾加快開機，尚未證實修復本案。
3. **ASUS 先看燈號與 Input。** 查得 VG289Q 手冊未列 DP/HDMI Deep Sleep，不能套用其他 ASUS PG 系列的設定。完整後綴尚待確認。
4. **比對 NVIDIA 驅動。** 官方歷史記錄有長時間螢幕睡眠後喚醒穩定性問題 5089560，以及特定螢幕無法喚醒問題 5806798/5635230；目前安裝版本與是否命中仍未知。

依據與操作界線均見上方完整研究；下文保留一般電源狀態排查。

## 症狀

一張 NVIDIA GeForce RTX 5070 Ti 顯示卡以 HDMI 與 DisplayPort (DP) 連接兩台主要螢幕 Acer ET322QK、ASUS VG289；另有接顯卡 HDMI 的 Philips FTV，使用 Win+P 切換。Acer/ASUS 的逐台介面對應尚待確認。長時間離席後回來，兩台主要螢幕常需按實體電源鍵才恢復顯示。辦公室桌機與筆電則能由滑鼠移動喚醒。目標是閒置時螢幕變黑，回來移動滑鼠便恢復；是否保留整機睡眠可依確認後的結果選擇。

## 初步結論

最值得先分辨的是「只有顯示器關閉」還是「整台電腦進入睡眠」。Windows 將兩者設為不同計時器；若桌機進入睡眠，滑鼠必須能喚醒主機，喚醒後顯示卡與兩台螢幕還要完成重新連線。若 Windows 仍運作但顯示器沒畫面，較像螢幕深度省電、輸入來源/握手、線材或顯示驅動的恢復問題。

辦公室設備可能只關閉面板而未讓主機睡眠，也可能成功從睡眠恢復；螢幕與輸入裝置設定同樣有影響。NVIDIA 標準規格列三個 DP、一個 HDMI，實卡廠商配置可不同，例如 ASUS TUF 有兩個 HDMI。運算性能與連接埠數不能判定喚醒原因。

DP 可能比 HDMI 更容易暴露顯示器睡眠後的重新偵測差異。ASUS 說明其特定產品的 DP 睡眠可令 Windows 將螢幕視為拔除，恢復時再重新連接；部分 ASUS 顯示器手冊更建議遇到無法喚醒時停用 DP/HDMI Deep Sleep。這證明一類可能機制，不代表未知型號的螢幕一定採相同設計。

## 建議排查順序

### 1. 先記錄故障時主機是否仍醒著

下次黑屏先不要按螢幕電源。觀察主機電源燈、風扇、鍵盤 Caps Lock 指示燈，並試著按鍵盤或播放聲音。若主機已睡眠，滑鼠/鍵盤喚醒能力是第一個檢查點；若主機仍工作且只有兩台面板無畫面，優先查顯示訊號恢復。

### 2. 暫時設定成「關螢幕但不讓主機睡眠」做對照

Windows 11：**設定 → 系統 → 電源與電池 → 螢幕、睡眠與休眠逾時**。將「關閉螢幕」設為使用者想要的時間，暫時將「讓裝置進入睡眠」設為「永不」，只作為短期診斷。Microsoft 明確將兩個計時器分列。若此時移動滑鼠可以穩定恢復，問題在原本的電腦睡眠/喚醒路徑或其喚醒後的顯示重新連線，而非單純的螢幕關閉。

診斷完可再決定桌機是否要睡眠；持續不睡會增加耗電，不宜誤當成已找到根因。

### 3. 若主機未睡、螢幕仍需按鍵

- 依型號手冊查看 OSD，先記下原值，一次只改一項。Acer 優先測試固定 Input/Auto Source，Quick Start 另作對照；ASUS VG289Q 先確認燈號與輸入。僅實機確實有 Deep Sleep 才測試該選項，不能假定 VG289 有它。
- 確認 Win+P 和 Windows 顯示設定中兩台主要螢幕都啟用；另做拔除 Philips HDMI 的對照，調查三台配置是否影響恢復。
- 分開測試：只接 HDMI 螢幕、只接 DP 螢幕、交換顯示卡輸出埠。確認是某一螢幕、DP 路徑、某一埠，還是雙螢幕組合才出現。
- 檢查直連顯示卡，暫時移除 KVM、擴充器、轉接器或延長線；有條件時換短且已知正常的線材。
- 黑屏時按 **Win+Ctrl+Shift+B** 可要求 Windows 重設圖形驅動；Microsoft 說明成功時可能聽到提示音或看到畫面閃動。這是診斷/暫時恢復手段，不是已修好證據。

### 4. 若主機確實睡眠

- 檢查 Windows 睡眠逾時，以及滑鼠/鍵盤在裝置管理員電源管理頁是否允許喚醒；若無效，取得 `powercfg /lastwake`、`powercfg /devicequery wake_armed` 與 `powercfg /a` 輸出再判讀。
- 更新 Windows、主機板 BIOS/晶片組與 NVIDIA 官方顯示驅動。記錄目前版本和更新日期；若症狀明確緊接某次更新才發生，才考慮回復該版本並比較。
- 暫不套用舊款卡專用的 DP 韌體更新工具：NVIDIA 公布的 DP 1.3/1.4 更新工具列出的支援卡為較舊系列，未列 RTX 5070 Ti；且其說明聚焦啟動時空白畫面/卡住，不等於本案的休眠喚醒修正。

## 目前可用的判斷

描述中「常常」需要手動按兩台螢幕電源鍵，與單一螢幕故障相比，較值得先檢查共用因素：整機睡眠狀態、Windows 計時器、喚醒後 GPU 重建雙螢幕輸出，以及兩台顯示器共同的深度省電/訊號偵測行為。這是依症狀做的排查排序，不是統計機率或確診。

若只需立刻貼近辦公室習慣，最小測試是先保留螢幕關閉計時器、暫時停用主機睡眠；若問題仍在，再檢查螢幕 OSD 的 Deep Sleep。實際永久設定應以桌機是否需要夜間睡眠、耗電及安全需求決定。

## 尚缺資料

要判定根因，還需要 Windows 版本、主機板與 BIOS、5070 Ti 廠牌/型號、NVIDIA 驅動、ASUS 完整後綴、Philips 完整機型、逐台介面對應、滑鼠接法、解析度/更新率與電源逾時。故障時記錄主機是否已醒、兩台燈號、Win+P 模式、No Signal，以及電源鍵一次或先關再開才恢復。

## 來源

- Microsoft： [Windows 11 電源設定](https://support.microsoft.com/en-us/windows/experience/power-battery/power-settings-in-windows-11)（螢幕關閉與裝置睡眠為分開的逾時設定）
- Microsoft： [Windows 黑畫面疑難排解](https://support.microsoft.com/en-us/windows/hardware/display-graphics/troubleshooting-blank-screens-in-windows)（連接檢查、Win+Ctrl+Shift+B 與顯示模式檢查）
- NVIDIA： [GeForce RTX 5070 系列規格](https://www.nvidia.com/en-us/geforce/graphics-cards/50-series/rtx-5070-family/)（5070 Ti 標示 3×DP、1×HDMI）
- ASUS： [多螢幕 DP 睡眠與重新連線說明](https://www.asus.com/us/support/faq/1044064/)（其適用型號/情境中 DP 螢幕睡眠可被 Windows 視為拔除；HDMI 行為不同）
- ASUS： [Deep Sleep 無法喚醒說明](https://www.asus.com/sg/support/faq/1050272/)（特定顯示器提供停用 DP/HDMI Deep Sleep 的處理方式）
- NVIDIA： [DP 1.3/1.4 顯示器韌體更新工具](https://www.nvidia.com/en-us/drivers/nv-uefi-update-x64/)（列出的支援產品不包含 RTX 5070 Ti；症狀範圍是開機空白/卡住）

廠商相容性說明僅用於界定各自產品行為；已取得主要螢幕系列名稱，但實際版本、設定與故障狀態仍待比對。
