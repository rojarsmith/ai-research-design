[English](2026-10-12-device-manager-live-scan.md) | **繁體中文**

# 個案 002：Bluetooth 服務節點與 USB 集線器重設失敗

狀態：**調查中；已定位裝置拓撲，實體根因未確認**。

蒐集日期：2026-10-12，首次實機快照為 10:36:40 UTC+08:00。使用者授權讀取 PC 裝置清單；使用 `Get-PnpDevice`、`Get-PnpDeviceProperty`、CIM 型號／組建查詢與 `pnputil /enum-devices ... /drivers`，另查故障邏輯路徑的歷史 USB 紀錄。未啟用／停用裝置、安裝／移除驅動，亦未由代理重啟或拔除硬體。本報告省略 Bluetooth 位址與完整執行個體 ID。

## 使用者觀察

- 四個 Other devices 曾由使用者手動停用，因 Windows Update 及產品廠商資源未解決原問題。
- Redmi Buds6 的播放與麥克風正常。
- 使用者表示拔除後 USB 錯誤會消失，但未指明拔除的是哪個裝置／連接。後續回覆表示人不在 PC 前，因此沒有進行受控實體測試。
- 實機掃描當時，Unknown USB Device 仍存在；這不與先前拔除測試的回報矛盾。

## 電腦與正常節點

- 主機板：CIM 回報 ASUS PRIME X870-P，勿改用 WIFI 版支援套件。
- OS：Windows 11 Pro N，回報組建 26300。本報告不據此推斷發行通道或歸因於 OS 組建。
- 網卡：Realtek Bluetooth 5.3 Adapter，硬體 ID `USB\VID_0BDA&PID_A729`，驅動 `1.9.1051.3002`，狀態 OK／問題碼 0。
- Redmi 播放（`BthA2dp`）、Hands-Free 音訊（`BthHFAud`）、Hands-Free AG 與 AVRCP 傳輸節點回報 OK／0；使用者另外確認播放／麥克風正常。
- Bluetooth 網卡接在正常的 Generic USB Hub `VID_0BDA&PID_5411`，路徑為 AMD 控制器邏輯根埠 2，再經下游埠 2。故障 USB 節點在同控制器的根埠 4 路徑；共用控制器不代表共同故障。

## 四個 Other devices 的實際對應

以下用各 BTHENUM 服務執行個體的遠端位址片段，比對遠端裝置紀錄；位址本身未寫入報告。

| 顯示名稱 | 對應周邊 | 服務 UUID | 實機問題碼 | 判讀 |
| --- | --- | --- | --- | --- |
| Bluetooth Peripheral Device | LOXJIE A40 | `0000180f-0000-1000-8000-00805f9b34fb` | 22 | 廣告的 Battery Service UUID；不代表擴大機真的有電池，也未解釋為何宣告此服務 |
| Redmi Buds6 | Redmi Buds 6 | `0000fd2d-0000-1000-8000-00805f9b34fb` | 22 | 與正常音訊端點分開的額外服務，此處未確認確切功能 |
| RFCOMM COM | Redmi Buds 6 | `df21fe2c-2515-4fdb-8886-f12c4d67927c` | 22 | 符合 Google Fast Pair 訊息串流的 RFCOMM UUID |
| WATCH | Redmi Buds 6 | `99999999-9999-9999-9999-999999999999` | 22 | 同一副耳機的額外自訂端點，此清單中不是另一支手錶；確切用途未知 |

電池 UUID 比對來源：[Bluetooth SIG Assigned Numbers](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Assigned_Numbers/out/en/Assigned_Numbers.pdf)。RFCOMM 比對來源：[Google Fast Pair 訊息串流](https://developers.google.com/nearby/fast-pair/specifications/extensions/messagestream)。

這四個停用端點的 PnP 屬性未提供綁定的驅動 INF／提供者／版本；PnPUtil 回報 Disabled，此次掃描未列出配對驅動。不能因此斷定其他來源不存在適當驅動，也不能還原停用前的原始錯誤。[Code 22](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/cm-prob-disabled) 只描述目前停用狀態。

判斷：必要耳機音訊正常，而這些額外服務被停用；不需要其功能時，維持停用合理。四筆本身未提供 Bluetooth 網卡或耳機硬體不穩定的證據。不能假設更新驅動就能實作每個廣告服務，也不用只為改變圖示就全數啟用。

## USB 故障：實機狀態

- 名稱：Unknown USB Device (Port Reset Failed)。
- 目前存在，問題碼 **43**。
- 硬體／配對 ID：**`USB\RESET_FAILURE`**；目前佔位 VID／PID 不能識別成品。
- 綁定驅動：Microsoft **`usb.inf`**，版本 `10.0.26100.9444`；PnPUtil 顯示它是重設失敗識別碼下的已安裝／最佳配對驅動。故障節點已有驅動，與 Code 28 缺驅動不同。
- 邏輯位置：**`Port_#0004.Hub_#0003`**。
- 路徑：**`ACPI(_SB_)#ACPI(PCI0)#ACPI(GP17)#ACPI(XHC1)#ACPI(RHUB)#ACPI(PRT4)`**。
- 父節點：USB Root Hub (USB 3.0)，再到 **AMD USB 3.10 eXtensible Host Controller - 1.20 (Microsoft)**；控制器位置為 PCI bus 115、device 0、function 4，兩個父節點都回報 OK。

埠／Hub 編號是 Windows 邏輯拓撲標籤，不能直接當成已驗證的後面板實體埠編號。父節點正常，也不能排除單一埠、連線、韌體或間歇性硬體問題。[Microsoft USB 列舉說明](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/case-study--troubleshooting-an-unknown-usb-device-by-using-etw-and-netmon)。

### 相同邏輯路徑的歷史身分

| 紀錄時間（UTC+08:00） | PnP 紀錄 |
| --- | --- |
| 2026-10-07 15:41:05.286 | Generic SuperSpeed USB Hub，`USB\VID_0BDA&PID_0411&REV_0117`，同一 PRT4 路徑的最後到達 |
| 2026-10-07 15:41:07.872 | 該 Hub 紀錄的最後移除；PRT4 → USB(1) 的下游 SuperSpeed Hub 也有相近到達／移除時間 |
| 2026-10-07 15:41:45.914 | 同一 PRT4 路徑上，目前重設失敗節點的最後到達 |

歷史 Hub 節點目前為未存在。到達／移除是 PnP 生命週期中繼資料，不代表首次故障時間、真的拔過線，或目前失敗物件一定就是原本那一件。

**工作假設：**優先調查該路徑的 USB 3.x 集線器連接，包括 Hub／上行線、供電與 PC 埠／控制器路徑。過去的 SuperSpeed Hub 身分，比盲目尋找「Unknown USB Device 驅動」更有調查價值。仍正常的 USB 2.x Hub／Bluetooth 路徑，可能是同一實體 Hub 的另一側，但尚未驗證實體對應，也未確認 Hub 成品型號或哪個元件故障。

## 有人在 PC 前時的下一輪測試

1. 確認拔除哪台 Hub／擴充座／KVM／螢幕的上行連接，會使目前故障節點消失。先儲存工作，下游儲存裝置安全退出；唯讀遠端清單不能代替實體測試。
2. 保持下游配置，改用已知良好且相容的上行資料線；觀察確切故障路徑，不混入無關裝置。
3. 該 Hub 直接接另一個適當 PC 埠，再換另一台相容 PC，確認 SuperSpeed Hub 可成功列舉且原負載穩定。
4. 用良好線材跨 PC 仍跟著 Hub 故障，才往 Hub 韌體／硬體查；跟著線材則換線。多個良好裝置只在同一 PC 埠／路徑失敗，才查該路徑。受控軟體回復改變結果時，保留版本證據。

未變更 USB 設定、移除控制器、修改選擇性暫停或更新韌體。先前 Kernel-Power 41 重啟的因果仍未證明。[通用個案指南](../research/device-manager-bluetooth-usb.zh-TW.md) · [主報告](../README.zh-TW.md)。
