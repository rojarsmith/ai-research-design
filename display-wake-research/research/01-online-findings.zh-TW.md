# 網路證據、實際螢幕型號與喚醒原因

查核日期：2026-10-14。這是公開資料研究與使用者提供的配置紀錄，尚未在問題電腦執行設定變更或重現測試。

## 本次新增的配置資訊

使用者確認主要螢幕是 **Acer ET322QK** 與 **ASUS VG289**，一台 HDMI、一台 DP；**Philips FTV** 也接顯示卡 HDMI，透過 **Win+P** 切換使用。Acer/ASUS 的線材對應尚未明確逐台確認；ASUS 型號後綴、Philips 完整機型及顯示卡廠牌型號仍未知。FTV 這個名稱不足以選出特定 Philips 手冊。

目前應以「兩台主要螢幕＋第三台透過 Windows 切換的 HDMI 顯示裝置」研究。沒有證據顯示使用了硬體 HDMI 切換器。也不能用 NVIDIA 標準連接埠數否定使用者的接法：例如 ASUS TUF RTX 5070 Ti 的實卡規格列出兩個 HDMI。這個例子只說明不同實卡可有不同輸出配置，不代表已識別使用者的卡。[ASUS 實卡規格](https://www.asus.com/ro/motherboards-components/graphics-cards/tuf-gaming/tuf-rtx5070ti-16g-gaming/techspec/)

## 目前最有價值的判斷

你要的滑鼠喚醒習慣是合理的；要做到這點，Windows 必須收到滑鼠事件、需要睡眠時能喚醒主機、GPU 要恢復正確輸出、螢幕要在收到訊號時恢復顯示。上述任一環節失敗都能呈現黑屏。昂貴或運算效能較高的顯示卡，不能單憑性能保證這些元件的喚醒相容性。

本次資料對「5070 Ti 是不是可能涉及驅動問題」給出更具體的證據：NVIDIA 歷史修正紀錄包括長時間顯示器睡眠後的喚醒穩定性問題，以及特定螢幕無法從睡眠喚醒的問題。它們值得和目前安裝版本比對，但尚不能證明這台電腦命中了其中任一問題。

## Acer ET322QK：先查來源選擇與 Quick Start Mode

Acer 官網 ET322QK 系列手冊記載省電後偵測到訊號可恢復；System 選單有 **Input、Auto Source、DP Format、Quick Start Mode**。手冊說明 Quick Start Mode 用於加快開機，未承諾能修復長時間休眠喚醒。不同版本手冊/OSD 有差異，依實機選單比對。[Acer 英文手冊](https://global-download.acer.com/GDFiles/Document/User%20Manual/User%20Manual_Acer_1.0_A_A.pdf?acerid=637467234446678758)

針對本案的推論：先固定實際接線的 Input 並測試關閉 Auto Source，觀察是否避開睡眠後錯誤搜尋來源；再獨立測試 Quick Start Mode 開啟。兩項不要同時改，改善結果才能指向原因。這是實驗設計，並非 Acer 已公告的 5070 Ti 修正。

部分 Acer 官方繁中版本還列出 Power-off USB Charge，但這指的是省電/關機時 USB 供電，不應誤解為「螢幕自動關機計時器」。只有使用者真的把滑鼠接在該螢幕 USB 上，才有理由追查這條路徑。[Acer 繁中手冊](https://global-download.acer.com/GDFiles/Document/User%20Manual/User%20Manual_Acer_1.0_A_A.pdf?acerid=637224415220033746)

## ASUS VG289：不要套用其他 ASUS 的 Deep Sleep 選單

查到的官方手冊涵蓋 **VG289Q**；完整後綴尚待確認。它記載白燈為開機、橘燈為待機，並提供 Power Indicator 開關；System Setup 有 ECO Mode，**未列出 DP Deep Sleep / HDMI Deep Sleep**。因此原報告的泛用 Deep Sleep 建議，不能當成 VG289Q 的具體操作。[ASUS VG289Q 手冊](https://dlcdnets.asus.com/pub/ASUS/LCD%20Monitors/VG289Q/ASUS_VG289Q_English.pdf)

先開啟 Power Indicator，讓故障時有燈號可觀察；確認 Input Select 正確。ECO Mode 可作後續單項對照，但手冊未說它會導致喚醒失敗，不能將 ECO 與深度睡眠畫上等號。

## Philips 與 Win+P：有訊號送去哪裡，也會影響看起來是否喚醒

Microsoft 說明 Win+P 用來選擇單一螢幕、同步顯示、延伸或第二螢幕等投影模式。在三台設備配置下，應到 **設定 → 系統 → 顯示 → 識別**，記下各機型對應編號與哪些顯示器正在啟用；不能只根據「第二個 HDMI」推定 Windows 的顯示器編號。[Microsoft 多螢幕使用說明](https://support.microsoft.com/en-us/windows/hardware/display-graphics/how-to-use-multiple-monitors-in-windows)

針對本案的推論：若離席前輸出模式仍是 Philips 使用狀態，回來時 Acer/ASUS 可能根本沒有被啟用。這可以造成黑屏，但尚未證明能解釋「按兩台螢幕電源鍵便恢復」。反過來，若按螢幕電源讓 Windows 重新偵測，也可能改變顯示配置。需要比較 **切回原本模式即可恢復** 與 **必須重啟螢幕** 兩種結果。

最有辨別力的對照是先從顯卡端拔除 Philips 的 HDMI，只保留兩台主要螢幕與固定配置，維持原本關屏/睡眠計時器，等到原本常出問題的離席時間。之後接回 Philips，測試切換前後是否有差異。這能調查第三台設備參與連線偵測的可能性；目前沒有確認 Philips 的 EDID、待機或 HDMI 控制行為。

## 網路上確實有「要按螢幕按鍵才亮」的官方案例

| 官方記錄 | 已記載的情況 | 適用邊界 |
| --- | --- | --- |
| [Dell 000202876](https://www.dell.com/support/kbdoc/en-us/000202876/gsync-r4-models-connected-with-hdmi-deep-sleep-mode-wake-up-fails) | AW2521H、AW2721D、AW3423DW、AW3821DW 透過 HDMI 深度睡眠後，滑鼠/鍵盤無法喚醒；建議按 OSD 或電源按鍵 | 不是 Acer/ASUS 本案型號；證明 HDMI 也可能有這類相容性問題 |
| [ASUS FAQ 1050272](https://www.asus.com/sg/support/faq/1050272/) | 部分 PG 系列進入 Deep Sleep 後無法喚醒，建議按螢幕按鍵或停用該功能 | 適用清單不包含 VG289Q；只能作機制參考 |
| [ASUS ProArt FAQ 1044064](https://www.asus.com/us/support/faq/1044064/) | 部分型號 DP 睡眠被 Windows 視為斷線、喚醒後重接，可能移動視窗 | 不能泛化為所有 DP 都會斷線，亦不能推論 HDMI 必定正常 |
| [LG 自動關機說明](https://www.lg.com/us/support/help-library/lg-monitor-i-want-to-know-how-to-schedule-autooff--20154629827412) | 部分顯示器有自身的 Automatic Standby/定時關機設定 | 目前沒有確認 Acer/ASUS 有相同計時器，Philips 尚缺完整型號 |
| [BenQ KVM 喚醒 FAQ](https://www.benq.com/en-us/support/downloads-faq/faq/product/troubleshooting/monitor-faq-kn-00021.html) | 滑鼠/鍵盤接螢幕 USB Hub 時，待機供電及 KVM 綁定影響主機喚醒 | 只有滑鼠經螢幕/Hub/KVM 時才追查；未確認本案採此接法 |

## NVIDIA 驅動：已查到的相關修正與容易混淆的事件

| 版本與日期 | 事件/官方記錄 | 和本案的關係 |
| --- | --- | --- |
| Studio 572.60，2025-02-27 | 長時間螢幕睡眠後喚醒的驅動穩定性問題，5089560 | 症狀接近；目前使用版本未知，不能直接要求回裝舊版 |
| 576.80，2025-06-17 的官方歷史列表 | DP 1.4 螢幕接 DP 2.1 顯卡的隨機黑屏閃爍，5277453 | 是相容性/閃爍記錄，未限定發生在長時間休眠後 |
| Hotfix 610.52，2026-06-08；610.62，2026-06-16 | 部分螢幕無法從睡眠喚醒，5806798 / 5635230 | 直接相關的問題類型，但沒有提供能確認本案型號命中的清單 |
| 同期其他修正 | RTX 50 **筆電** Modern Standby 黑屏、開機 DP 黑屏、特定 LG DP 2.1 HDR 黑屏 | 平台/觸發條件不同，不能拿來證明這台桌機的原因 |

來源：[NVIDIA Studio 歷史修正列表](https://www.nvidia.com/Download/processFind.aspx?dtcid=1&lang=en-us&lid=1&osid=57&pfid=930&whql=4)、[NVIDIA 員工發布的 610.52 公告](https://www.nvidia.com/en-us/geforce/forums/game-ready-drivers/13/586981/announcing-geforce-hotfix-driver-61052-released-68/3612710/)、[610.62 官方索引](https://www.nvidia.com/Download/processFind.aspx?dtcid=1&lang=en-us&lid=1)。部分 NVIDIA 動態頁直接開啟只有 JavaScript 提示；上述細節由搜尋索引中的官方內容核對，沒有取得完整修正內部分析。報告列的是歷史版本，沒有把它們稱為 2026-10-14 的最新版。

合理的處理是記下已安裝版本、症狀開始日期及近期更新，再從官方為該卡/Windows 提供的現行版本中比較。一旦發現某次更新引入問題，可測試最後已知正常且支援 5070 Ti 的版本。不能僅以 Game Ready/Studio 名稱認定哪一個一定能解決喚醒；兩者可能共享相關修正。

## Windows：移動滑鼠、按滑鼠與電腦睡眠是不同條件

Windows 將關屏與睡眠計時器分開；S3 睡眠、Modern Standby 與 S4 休眠的恢復條件也不同。先使用 `powercfg /a` 確認這台支援何種狀態，不能根據「桌機」或「筆電」就預設某一種。[電源設定](https://support.microsoft.com/en-us/windows/experience/power-battery/power-settings-in-windows-11)、[系統電源狀態](https://learn.microsoft.com/en-us/windows/win32/power/system-power-states)

Modern Standby 文件將外接滑鼠的按鍵列為喚醒動作；Bluetooth 滑鼠的移動喚醒是可選能力。因此「移動沒反應、點擊有反應」有助識別輸入喚醒路徑。文件也提到 Windows 11 24H2 起電池過度消耗可能限制喚醒來源，這不應直接套用到未知睡眠狀態的插電桌機。[Modern Standby 喚醒來源](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/modern-standby-wake-sources)

保留主機睡眠也有可能達成你的習慣；暫時設成永不睡眠的用途是隔離原因。鍵盤燈、風扇只作線索，不能單憑它們確認 Windows 電源狀態，應搭配睡眠紀錄。

## 依證據安排排查順序

先記錄原設定；每個條件至少比較數次，包含原本容易出問題的長時間離席。短時間恢復正常不能代表長時間問題已修好。

| 次序 | 只改/觀察這件事 | 如何解讀 |
| --- | --- | --- |
| 1 | ASUS 打開 Power Indicator；故障時記錄兩台燈號、是否有 No Signal、電源鍵要按幾次 | 區分待機、已關機、顯示有供電但無影像；燈號熄滅仍先排除指示燈被停用 |
| 2 | 故障時先移動滑鼠，再點滑鼠、按鍵盤；觀察主機是否醒來 | 點擊/鍵盤成功而移動失敗，優先查滑鼠喚醒能力；主機已醒但無影像則查顯示鏈 |
| 3 | 確認 Win+P 已回到平常模式，顯示設定中 Acer/ASUS 都啟用 | 切回即可恢復，優先處理投影配置；未恢復才繼續 |
| 4 | Philips HDMI 從顯卡端拔除，其他設定保留 | 問題消失才加強調查三台配置與切換恢復，不能直接判 Philips 故障 |
| 5 | 保留關屏時間，暫時將主機睡眠設為永不；檢查另有無休眠逾時 | 若改善，縮小至整機睡眠/喚醒後恢復；未改善則關屏/顯示鏈仍有問題 |
| 6 | Acer 固定 Input、停用 Auto Source；另一次測試 Quick Start Mode On | 測試來源搜尋和啟動恢復；未證實前保持假設 |
| 7 | 只接一台，再交換兩台的 HDMI/DP 接法或換已知正常線材 | 跟螢幕走、跟介面走與只有多螢幕時失敗，指向不同原因；交換線材與介面是組合對照，後續再分拆 |
| 8 | 記錄驅動後做一次官方驅動更新/有根據的回復 | 以相同配置及長時間離席結果比較，避免同時改 BIOS 和其他設定 |

若主機確定醒著卻仍黑屏，可試 **Win+Ctrl+Shift+B** 重設圖形驅動。若兩台一起恢復，增加追查共用顯示恢復路徑的理由；這個動作成功仍無法唯一判定是 GPU 驅動或顯示器重新握手。[Microsoft 黑畫面排查](https://support.microsoft.com/en-us/windows/hardware/display-graphics/troubleshooting-blank-screens-in-windows)

## 讀取資訊的指令

在問題電腦的終端機逐行執行，保存文字即可；這些指令不變更電源設定。`/lastwake` 請在失敗後成功恢復的當次讀取。

```powershell
powercfg /a
powercfg /getactivescheme
powercfg /query
powercfg /devicequery wake_armed
powercfg /devicequery wake_programmable
powercfg /lastwake
```

`/a` 是可用狀態而非此次實際入睡證據；`wake_armed` 是已設定能喚醒的裝置，不保證硬體路徑正常；`/lastwake` 不記錄每次單純關屏恢復，空白也不證明沒發生問題。必要時以系統事件與 `powercfg /systemsleepdiagnostics` 補足；後者需系統管理員、會生成報告檔。SleepStudy 適用 Modern Standby，不是所有電腦都適用。[Microsoft powercfg 文件](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/powercfg-command-line-options)

## 不應當成預設解法的網路建議

- **一律停用 USB Selective Suspend：** Microsoft 建議保留選擇性暫停；先確認滑鼠/Hub 的實際故障路徑，再做有範圍的對照。[Microsoft USB 文件](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/usb-selective-suspend)
- **一律設定 NVIDIA「最高效能」：** 目前查得資料沒有證明能修復這組螢幕的長時間喚醒；先比對版本與投影配置。
- **一律關 Fast Startup：** Microsoft 的 Fast Startup 說明屬於關機後的混合啟動路徑；若只是關屏或睡眠，不能把它列為已證實原因。
- **把 DDC/CI 當喚醒總開關：** 手冊記載它用於電腦軟體控制螢幕設定，不能等同滑鼠一定能喚醒。
- **先重裝 Windows、換顯卡或刷舊 DP 韌體：** 現有證據不足；先完成低成本對照。舊 NVIDIA DP 更新工具未列 5070 Ti，而且處理的是開機問題。

## 尚未確定的事項

仍需要：兩台的 HDMI/DP 對應、ASUS 完整後綴、Philips 真正機型、Windows 組建、NVIDIA 驅動版本、滑鼠是 USB 接收器/有線/Bluetooth 以及接在哪裡。最重要的故障觀察是主機是否已醒、兩台燈號、Win+P 所選模式、電源鍵一次或關再開才能恢復。這些資料比繼續蒐集泛用「黑屏」文章更能縮小根因。

更多查證細節見[來源與證據界線](02-sources.zh-TW.md)，測試紀錄可使用[觀察範本](../cases/observation-template.md)。
