[English](device-manager-bluetooth-usb.md) | **繁體中文**

# 裝置管理員：Other devices 與 USB 埠重設失敗

查核日期：**2026-10-12**。個案來源：`Screenshot 2026-10-12 102507.png`。這是依截圖提出的調查流程，未修改裝置設定或驅動。

更新：經授權的[實機掃描](../cases/2026-10-12-device-manager-live-scan.zh-TW.md)已識別停用服務與故障 USB Hub 路徑。最新事實請見該個案；下方截圖判讀保留最初證據界線。

## 截圖能確認什麼

| 可見項目 | 判讀 | 尚需資料 |
| --- | --- | --- |
| Bluetooth Peripheral Device | 通用名稱，可能是 Bluetooth 服務節點 | 狀態碼、硬體／相容識別碼、父裝置及預期功能 |
| Redmi Buds6 | 名稱看似已配對周邊，無法確定失敗的是哪個設定檔 | 同上，另確認播放與麥克風是否正常 |
| RFCOMM COM | 名稱看似 Bluetooth 序列／服務端點 | 硬體 ID／服務 UUID，以及是否需要序列通訊 |
| WATCH | 名稱本身不能確定品牌、型號或服務 | 父裝置、ID 與預期手錶整合功能 |
| Unknown USB Device (Port Reset Failed) | 明確顯示 USB 埠重設失敗與黃色警告 | 裝置狀態、位置／父裝置、硬體 ID 與連接路徑 |

前四個 Other devices 圖示看起來有向下箭頭。**使用者隨後確認曾手動停用**，因為 Windows Update 與產品廠商官網資源未能解決原問題。現在的停用狀態不能證明先前是哪個故障碼，不應把四項全部判成缺驅動。同一周邊可能產生多個服務節點，不代表四件硬體都壞了。Windows 依識別碼與 INF 配對載入 Bluetooth 設定檔驅動。[Bluetooth 驅動堆疊](https://learn.microsoft.com/en-us/windows-hardware/drivers/bluetooth/using-the-bluetooth-driver-stack)。

截圖不能證明這些裝置造成先前 Kernel-Power 41 重啟。多個 AMD／ASMedia 控制器與 Generic USB Hub 的數量，本身不代表故障。

## 先讀狀態，再選修法

逐項按右鍵 → **內容**：

1. **一般 → 裝置狀態**：複製完整訊息與代碼。
2. **詳細資料 → 硬體識別碼、相容識別碼、父系、位置路徑**：複製可用值。硬體 ID 是 Windows 比對驅動的依據，與顯示名稱不同。[硬體 ID](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/hardware-ids)。
3. **驅動程式**：記錄提供者／版本／日期；**事件**：記錄安裝或啟動失敗。
4. 記錄 Windows 組建、主機板／PC 型號、Bluetooth 網卡型號及真正缺少的功能。不能由截圖的 USB 控制器名稱判斷 Bluetooth 網卡型號。

| 已確認代碼 | 意義與下一步 |
| --- | --- |
| 22 | 裝置已停用。刻意停用且不需要時可維持；需要該功能時啟用該項，再看新的狀態。啟用不會自動解決缺驅動。[Code 22](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/cm-prob-disabled) |
| 28 | 驅動未完成安裝／缺少。先識別硬體或服務，再取得相符且受支援的驅動。[Code 28](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/cm-prob-failed-install) |
| 43 | Windows 因回報故障而停止裝置；單靠代碼不能區分裝置、連接或驅動原因。[Code 43](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/cm-prob-failed-post-start) |

這些是**裝置管理員問題碼**，不是事件檢視器 ID；截圖未顯示實際數字。

可選擇在 Windows PowerShell 執行唯讀清單：

```powershell
Get-PnpDevice -PresentOnly |
    Where-Object { $_.Status -ne 'OK' } |
    Format-List FriendlyName, Class, Status, InstanceId
```

這只列出目前存在的非 OK 裝置，不能證明原因，也不包含上方所有必要資料。Instance ID 可能含 Bluetooth 位址／序號，公開前應遮蔽，不需任意公開整份清單。

## Bluetooth：修復真正需要的功能

此個案下一步不再重複自動更新驅動。先識別端點／服務 ID，再確認播放、麥克風或其他必要功能是否真的失敗。不要只為消除停用標記就全數啟用；需要測試時，只啟用該必要端點並記錄新的問題碼，因為 Code 22 可能遮住先前問題。目前仍缺原始故障碼、確切 Bluetooth 網卡與已安裝驅動版本。

1. 若確認 Code 22，先了解為何被停用。只啟用需要的項目，再確認代碼；不需要時維持停用是合理選擇。
2. 若是 Code 28 或可重現 Bluetooth 故障，先在 Bluetooth 分類識別**真正的 Bluetooth 網卡**，再安裝對應 Windows 版本、由 PC／主機板／網卡廠商提供的驅動。顯示卡驅動或一般 AMD 晶片組套件不自動等於 Bluetooth 驅動。
3. 特定周邊仍失敗時，在「設定 → Bluetooth 與裝置」移除**該配對**後重新配對。這會中斷該周邊；若是滑鼠／鍵盤，先保留其他輸入方式。更新驅動與重新配對屬官方支援排查步驟。[Microsoft Bluetooth 排查](https://support.microsoft.com/en-us/windows/hardware/bluetooth/fix-bluetooth-problems-in-windows)。
4. Redmi Buds6 應測試播放與麥克風；WATCH／RFCOMM 則測試實際需要的功能。Bluetooth 網卡驅動不能憑空加入周邊廠商專用服務的支援。基本功能正常、僅選用服務無相符 Windows 設定檔時，可不使用該服務，或移除不需要的配對，勿強套無關驅動。[Bluetooth 裝置安裝](https://learn.microsoft.com/en-us/windows-hardware/drivers/bluetooth/installing-a-bluetooth-device)。

成功標準是預期功能正常且必要節點無持續問題；刪除節點後下次配對又出現，不算永久修復。

## USB：定位失敗的連接

埠重設屬 USB 列舉過程。重設逾時可能使 Windows 在取得有效廠商／產品資訊前就列為未知裝置。若 ID 是 `USB\UNKNOWN`、`USB\RESET_FAILURE` 或零值／佔位 VID／PID，不要拿它猜廠商。Microsoft 舊版個案說明了列舉問題，但其 Windows 7 追蹤工具流程不是現行通用修法。[USB 列舉個案](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/case-study--troubleshooting-an-unknown-usb-device-by-using-etw-and-netmon)。

建議依下列方式隔離：

1. 儲存工作，將非必要外接 USB **一次拔除一件**，每次重新查看裝置管理員。儲存裝置先安全退出，保留必要鍵盤／滑鼠，確認拔除哪件時錯誤節點消失。
2. 找到後繞過集線器／擴充座／前置埠，有條件時直接接主機板埠。測試已知良好且相容的資料線與其他埠，一次只換一項。
3. 可疑裝置／線材換到另一台 PC，另一件已知良好的同類裝置接到可疑埠。故障跟著裝置／線材走，線索偏向該側；不同裝置都在同一路徑失敗，偏向埠／集線器／控制器路徑，但不能單靠一輪就確認某元件故障。
4. 先關機再斷電重置。桌機可短暫斷開外部電源及獨立供電集線器，再接回開機；筆電／內建電池依製造商程序處理。暫時恢復可提供狀態問題線索，但不是永久修復證明。
5. 仍有問題時，只解除安裝**已識別的該筆 Unknown USB Device**，不要勾選移除驅動套件，再重新連接、掃描硬體變更或重啟。實體重設仍失敗時警告會回來；不要整批移除控制器或集線器。
6. 移除外接周邊後仍在，查看連接樹／位置路徑。可能是內建 Bluetooth、攝影機、讀卡機或其他內部 USB 元件，但截圖不能識別是哪件。可用「**檢視 → 依連線顯示裝置**」，必要時使用 Microsoft [USBView](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/usbview)。列舉失敗可能看不到名稱，但拓撲仍可協助定位埠。
7. 確認型號／路徑後，再查相關 OEM 晶片組／控制器／裝置驅動與韌體。xHCI 使用 Microsoft 驅動是正常情況，不需僅因提供者是 Microsoft 就換掉。[Windows USB 主機端驅動](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/usb-3-0-driver-stack-architecture)。內部線材隔離或韌體變更應依確切硬體的維修指引。

若只在睡眠／喚醒後發生，記錄觸發條件並調查已識別裝置的電源行為。不要把全域停用 USB 選擇性暫停當作預設修法；Microsoft 建議保持啟用。[選擇性暫停](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/usb-selective-suspend)。

驗證多次重新連接及原本負載；睡眠／喚醒原本有問題才納入測試。記錄重現情形及埠拓撲，不只看黃標是否暫時消失。若裝置用良好線材跨 PC 仍失敗，考慮裝置維修；若只固定在某台 PC／路徑，先調查該路徑再更換周邊。

## 與先前重啟的關係

將 USB／Bluetooth 實際失敗時間與 **6008 內的真正關機時間**比較。Kernel-EventTracing 28 則需先識別事件資料內的 GUID 才能比對。這些裝置與事件同時存在，不代表共同根因；應先重現並建立時間關聯，再歸因。

## 區分軟體支援與硬體不穩定

以下是依證據決定的調查方向，不是對廠商或微軟責任的判決：

| 受控觀察 | 調查方向 |
| --- | --- |
| 必要 Bluetooth 功能正常，只有已識別的選用服務沒有相符且受支援的設定檔／INF | 服務支援或驅動配對；單憑此情況不能證明硬體不穩定 |
| 同一 USB 裝置用良好線材在另一台 PC 也失敗 | 裝置硬體／韌體較值得查；仍需確認另一台 PC 支援它 |
| 故障跟著某條線或集線器移動，換成良好替代品就消失 | 線材／集線器路徑較值得查 |
| 不同良好裝置都只在同一實體埠／路徑失敗，其他地方正常 | PC 埠／集線器／控制器路徑；還需區分實體、韌體與驅動 |
| 問題從已識別的驅動／Windows 變更開始，受控回復後消失 | 軟體回歸較值得查，需保留版本及重現步驟 |
| 移除非必要外接裝置後錯誤仍在 | 查內部 USB 拓撲，不代表已證明主機板壞了 |

廠商驅動未修好不代表一定是微軟的責任，Windows Update 找不到更新也不代表硬體壞了。下一步所需資料：播放／麥克風實際情況、USB 狀態與硬體 ID，以及沒有非必要外接周邊時錯誤是否仍在。

[回主報告](../README.zh-TW.md) · [通用排查流程](workflow.zh-TW.md)
