# 來源與證據界線

查核日：2026-10-14。下表以第一方文件為主；產品手冊用於核對設定與狀態，驅動修正由 NVIDIA 說明，Windows 行為由 Microsoft 文件界定。廠商的故障說明不等於本機根因。未將論壇回覆、搜尋結果數量或其他使用者配置當成發生率統計。

| ID | 來源 | 實際查到的支持範圍 | 本案限制 |
| --- | --- | --- | --- |
| S01 | [Microsoft：電源設定](https://support.microsoft.com/en-us/windows/experience/power-battery/power-settings-in-windows-11) | 分開設定螢幕與裝置睡眠計時器 | 沒有讀取本機設定 |
| S02 | [Microsoft：系統電源狀態](https://learn.microsoft.com/en-us/windows/win32/power/system-power-states) | S0、S3、S4、Fast Startup 的不同路徑 | 本機狀態未識別 |
| S03 | [Microsoft：Modern Standby 喚醒來源](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/modern-standby-wake-sources) | 輸入裝置與喚醒顯示條件 | 只在本機確實使用此模式時套用 |
| S04 | [Microsoft：powercfg](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/powercfg-command-line-options) | 指令定義與報告用途 | 可用能力不等於一次故障的實際原因 |
| S05 | [Microsoft：多螢幕與 Win+P](https://support.microsoft.com/en-us/windows/hardware/display-graphics/how-to-use-multiple-monitors-in-windows) | 投影選項與顯示器識別 | 本機編號/啟用狀態未取得 |
| S06 | [Acer：ET322QK 英文手冊](https://global-download.acer.com/GDFiles/Document/User%20Manual/User%20Manual_Acer_1.0_A_A.pdf?acerid=637467234446678758) | PDF 14、25–26 頁：省電恢復與 System 選單 | 手冊頁碼與紙本章節頁碼不同；實機後綴/版本需比對 |
| S07 | [Acer：ET322QK 系列繁中手冊](https://global-download.acer.com/GDFiles/Document/User%20Manual/User%20Manual_Acer_1.0_A_A.pdf?acerid=637224415220033746) | PDF 14、26–27 頁：恢復、Quick Start Mode 與 USB 供電 | 比 S06 多 USB 相關選項，不將兩份當成完全相同實機 |
| S08 | [ASUS：VG289Q 英文手冊](https://dlcdnets.asus.com/pub/ASUS/LCD%20Monitors/VG289Q/ASUS_VG289Q_English.pdf) | PDF 11、21–22、24 頁：燈號、ECO、Power Indicator、排查 | VG289 後綴未確認；查得版本未列 Deep Sleep |
| S09 | [Dell：HDMI 深睡無法喚醒](https://www.dell.com/support/kbdoc/en-us/000202876/gsync-r4-models-connected-with-hdmi-deep-sleep-mode-wake-up-fails) | 000202876，2026-06-30 修訂，四款 Alienware | 症狀類似，本案主要型號不同 |
| S10 | [ASUS：PG 系列 Deep Sleep](https://www.asus.com/sg/support/faq/1050272/) | 2025-08-12 修訂，涵蓋部分 PG 系列 | 不涵蓋 VG289Q |
| S11 | [ASUS：ProArt DP 斷線與重接](https://www.asus.com/us/support/faq/1044064/) | 2025-05-05 修訂，指定 ProArt 清單 | 不泛化為 DP/HDMI 的必然行為 |
| S12 | [LG：Automatic Standby](https://www.lg.com/us/support/help-library/lg-monitor-i-want-to-know-how-to-schedule-autooff--20154629827412) | 顯示器可有自身關機計時器 | 不是 Acer/ASUS/Philips 已確認設定 |
| S13 | [BenQ：KVM 無法喚醒](https://www.benq.com/en-us/support/downloads-faq/faq/product/troubleshooting/monitor-faq-kn-00021.html) | USB 上行/待機供電影響滑鼠喚醒路徑 | 本案未知是否使用螢幕 Hub |
| S14 | [NVIDIA：Studio 驅動歷史索引](https://www.nvidia.com/Download/processFind.aspx?dtcid=1&lang=en-us&lid=1&osid=57&pfid=930&whql=4) | 572.60/5089560 與 576.80/5277453 的修正描述 | 使用官方搜尋索引內容；未取得完整內部修正細節 |
| S15 | [NVIDIA 員工：610.52 Hotfix 公告](https://www.nvidia.com/en-us/geforce/forums/game-ready-drivers/13/586981/announcing-geforce-hotfix-driver-61052-released-68/3612710/) | 2026-06-08 公告，5806798/5635230 | 採員工公告內容，未採下方一般回覆作確診；直接頁需 JS |
| S16 | [NVIDIA：610.62 官方歷史索引](https://www.nvidia.com/Download/processFind.aspx?dtcid=1&lang=en-us&lid=1) | 2026-06-16 列出相同喚醒修正 | 動態頁跨產品，明確對照 GeForce 區塊；不是當前最新版宣稱 |
| S17 | [ASUS：TUF RTX 5070 Ti 規格](https://www.asus.com/ro/motherboards-components/graphics-cards/tuf-gaming/tuf-rtx5070ti-16g-gaming/techspec/) | 實卡可有兩個 HDMI、三個 DP | 使用者實卡未識別 |
| S18 | [Microsoft：黑畫面排查](https://support.microsoft.com/en-us/windows/hardware/display-graphics/troubleshooting-blank-screens-in-windows) | Win+Ctrl+Shift+B 與連接檢查 | 成功恢復不會唯一識別根因 |
| S19 | [Microsoft：USB Selective Suspend](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/usb-selective-suspend) | 建議保留 USB 選擇性暫停 | 不排除有根據的個別裝置對照 |
| S20 | [NVIDIA：舊 DP 韌體工具](https://www.nvidia.com/en-us/drivers/nv-uefi-update-x64/) | 支援清單與開機黑屏/卡住問題 | 未列 RTX 5070 Ti，與本案觸發狀況不同 |

上述共 20 項第一方參考。S14–S16 的版本內容可由官方搜尋索引核對，但部分直接動態頁無法提供完整文字；這一取得限制已保留，不以第三方轉載補成完整官方證據。搜尋時遇到 BenQ 某份手冊 404 與 NVIDIA PDF 讀取失敗，未把未讀取內容納入已確認來源。

Acer 兩份手冊名稱同屬 ET322QK 系列，內容有版本差異。ASUS 官網還提供不同語言與不同後綴產品，完整實機型號到手後應重新對應。Philips FTV 尚未對應到唯一產品，所以沒有擅自引用某款 Philips 電視的定時器或 HDMI-CEC 設定。
