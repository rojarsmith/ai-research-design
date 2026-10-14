[English](2026-10-14-kingston-nvme-dropout.md) | **繁體中文**

# 無預警重啟後，開機 SSD 從 BIOS 消失

查核日期 **2026-10-14**，Asia/Taipei（UTC+08:00）。狀態：**根因未定；優先懷疑間歇性儲存裝置／控制器／連線失效**。本個案結合使用者觀察、截圖及已授權的唯讀查詢；未執行修復、效能測試、韌體更新或重啟。

## 改變排查方向的關鍵觀察

使用者表示本月發生兩次無預警重啟，每次 **KINGSTON SFYRD2000G 不只從開機選項消失，連 BIOS NVMe／儲存裝置清單也找不到，必須斷電再啟動才恢復**。這是 Windows 啟動之前的裝置列舉失敗，修復 Boot Manager 無法解釋此現象。可能包括 SSD 控制器／韌體卡住、M.2 接觸或 PCIe 連線、主機板與供電問題；仍無法確定哪個元件先引發崩潰，也不能排除 RAM／電源供應器。

實機確認 Kingston 是 Disk 1，**EFI 系統分割區與 Windows C: 都在上面**。C: 上也有分頁檔及設定的小型傾印。平台為 Ryzen 7 7700／ASUS PRIME X870-P，BIOS **1804**，SSD 韌體 **EIFK31.7**。調整硬體後必須重新確認磁碟編號。

## 為什麼溫度不同

| 讀值 | 證據 | 判讀 |
| --- | --- | --- |
| KSM Composite Temperature 51°C | Kingston SSD Manager 1.5.6.5 截圖／實機畫面 | 與主要綜合溫度欄位相符 |
| HWiNFO Drive Temperature 52°C | 截圖；主要讀值約 50–56°C 間變動 | 更新時間與四捨五入不同，差一度並不奇怪 |
| HWiNFO Drive Temperature 3 固定 91°C | 原始 NVMe **temperature sensor 2 = 364 K**，約 90.85°C | 另一個 SSD 回報欄位；名稱不能證明是第三個實體探頭或目前主控溫度 |

直接唯讀查詢的 composite 為 **49.85–50.85°C**。HWiNFO 開發者確認該名稱對應原始 sensor 2，但尚未從直接廠商規格確認 **EIFK31.7** 對這欄位的實體位置／歷史意義。保存峰值或特殊韌體定義是合理推測，仍不能當成定論；不要把 91°C 說成已證實的即時熱點，也不能逕自視為無害軟體錯誤。[HWiNFO 開發者說明](https://www.hwinfo.com/forum/threads/kingston-fury-renagade-not-showing-correct-temp.8836/)。

另外有**過去綜合溫度偏高**的證據：SSD 回報生命週期累積警告溫度時間 559 分鐘、臨界溫度時間 14 分鐘；Identify Controller 門檻約 **84°C／89°C**。計數器沒有事故時間戳，不能據此把高溫連結到十月的兩次當機。Kingston 對 composite 的定義依實作而定，不一定是某個元件的溫度。[Kingston SMART 定義](https://media.kingston.com/support/pdf/ssd-smart-attribute.pdf)。

同次讀取 critical warning **0**、備用空間 **100%**、percentage used **8%**、media/data-integrity errors **0**，仍無法排除控制器或連線間歇失效。「剩餘壽命 92%」是耐寫度估計，不是可靠度有 92%。Error-log 累積 **2,136** 筆；這次取回的五筆非空最近紀錄解碼為 **Invalid Field in Command**，不是壞磁區。不能用這五筆概括所有歷史紀錄，也無法確認是哪個程式送出指令。[Microsoft 狀態碼](https://learn.microsoft.com/en-us/windows/win32/api/nvme/ne-nvme-nvme_status_generic_command_codes)。

## Windows 記錄了什麼

| Event 6008 內記載的上次關機時間 | 下次開機的 Event 41 時間 | Event 41 記載的 Bugcheck |
| --- | --- | --- |
| 10 月 3 日 17:52:07 | 10 月 3 日 18:38:08 | 十進位 340 = **0x154 UNEXPECTED_STORE_EXCEPTION** |
| 10 月 14 日 15:34:47 | 10 月 14 日 17:54:57 | 十進位 30 = **0x1E KMODE_EXCEPTION_NOT_HANDLED**；參數 1 為 **0xC0000006 STATUS_IN_PAGE_ERROR**（XML 中有符號延伸） |

以上時間皆 UTC+08:00，是系統記載的關機時間，並非獨立量測的故障起始時間。0x154 涉及核心記憶體儲存，單靠它不能證明 SSD 故障。第二次例外表示讀入記憶體所需資料時發生 I/O 失敗；缺少傾印，無法識別負責的路徑／驅動。[0x154](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/bug-check-0x154--unexpected-store-exception)、[0x1E 參數](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/bug-check-0x1e--kmode-exception-not-handled)、[NTSTATUS 定義](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-erref/596a1078-e883-4972-9bbc-49e60bebca55)。

兩次開機都有 **volmgr 161 傾印建立失敗**，指向目前對應 C: 的磁碟區；未找到既有 memory／minidump。開機碟失聯可能解釋無法寫出傾印，但仍是假設。十月查詢未找到符合篩選的 stornvme 129、disk 157 或 WHEA 17–20；開機碟出問題也可能讓日誌寫不出來，因此缺少紀錄不能排除故障。

**D: 另有獨立問題需要處理：**Toshiba HDWN180 截圖有 **8 個待處理磁區**。十月日誌含 **61 筆 disk Event 7**，指向 Harddisk0，另有兩筆 Disk 0 重試事件（153）；目前 Disk 0 即這顆 Toshiba。紀錄筆數不等於不同壞磁區數，歷史編號也未必固定。不要把 D: 當唯一備份目的地。這些證據不能證明它造成 Kingston 從 BIOS 消失。

## 依序隔離與改善

1. **先將 C:、D: 無法取代的資料備份到確認健康的儲存裝置。**C: 目前約使用 1,492 GiB；E: 是 1 TB Crucial，剩餘約 525 GiB，無法容納 C: 完整複製，但可能放得下挑選的重要檔案。本次調查尚未替你執行備份。
2. **記錄正常使用，不刻意逼出當機。**用 HWiNFO 記錄會變動的 composite 溫度。若自然再發生，斷電前拍下 BIOS NVMe 清單，記下工作負載、時間及一般重啟是否仍無效。固定 91°C 欄位本身不能拿來驗證散熱改善。
3. **備份完成後，關機拔除電源再重新插妥。**檢查 SSD 接點、固定螺絲、散熱片接觸、導熱墊保護膜及風流；避免壓彎 PCB，保留原廠散熱層／標籤。若 composite 明顯升高，改善散熱有價值，但改善後穩定也不單獨證明故障元件。
4. **一次只改一項，進行交叉測試。**把 Kingston 移到另一個相容 M.2 插槽，使用相近負載觀察足夠時間。若可行，再用另一台 PC 的原生 NVMe 插槽測它，以及用已知正常 SSD 測原插槽。USB 外接盒改變連線與供電路徑，在那裡正常的證據較弱。故障跟著 Kingston 走，支持 SSD／送修方向；其他 SSD 在原插槽也失敗，支持主機板／連線／供電路徑。一回成功開機不足以判定修好。
5. **移動前核對確切主機板手冊。**PRIME X870-P 的 M.2_4 與 SATA6G_1/2 共用資源，移到此處可能停用已接的 SATA 裝置；邏輯 PCIe 路徑不能證明實體插槽標號。若 Kingston 在 Gen5 插槽，後續可單獨測試把該槽固定為 Gen4，保留原設定以便回復，僅變更這個選項。[ASUS 手冊](https://dlcdnets.asus.com/pub/ASUS/mb/SocketAM5/PRIME_X870-P/E23913_PRIME_X870-P_EM_WEB.pdf?model=PRIME+X870-P)。
6. **不要先做重複更新或檔案系統修復。**已裝 BIOS 1804 與 ASUS 目前最新公布版相符；EIFK31.7 是該型號列出的韌體，KSM 顯示「No Firmware Update Available」。目前沒有查證到適用的新版本修正。不要強刷另一韌體分支、初始化／格式化 C:，或備份前做重度表面掃描。[ASUS BIOS](https://www.asus.com/motherboards-components/motherboards/prime/prime-x870-p/helpdesk_bios?model2Name=PRIME-X870-P)、[Kingston 韌體](https://www.kingston.com/en/support/technical/ksm-firmware-update)。
7. **可現在就向 Kingston 建立支援／保固案件。**即使 media errors 為零，兩次 BIOS 層級失聯且需斷電恢復，已足以提出檢查要求。附型號／韌體、BIOS、兩次 bugcheck、溫度歷史與 BIOS 照片，請其明確解釋 EIFK31.7 的 sensor 2。保固是否適用仍需核對購買證明及條款；本次沒有代你聯絡廠商。

備份後，另可關機暫時拔除有疑慮的 Toshiba 進行隔離，因 EFI／OS／分頁檔都在 Kingston。先確認程式及資料相依需求；若目標是辨認原因，不要把拔除 D:、移 M.2、改散熱同時做。

## 可重用的唯讀蒐集

[Read-NvmeHealth.ps1](../scripts/Read-NvmeHealth.ps1) 在開啟磁碟前檢查型號及 NVMe 匯流排，再透過 Windows 儲存屬性查詢讀取 SMART、Identify Controller，並可選讀前八筆 error log；不重設、不寫入 SSD、不更新韌體。[Microsoft API 文件](https://learn.microsoft.com/en-us/windows/win32/fileio/working-with-nvme-devices)。

```powershell
# 先重新核對 Get-Disk；編號可能改變。必要時以管理員身分執行。
.\scripts\Read-NvmeHealth.ps1 -DiskNumber 1 -ExpectedModel 'KINGSTON SFYRD2000G' -IncludeErrorLog
```

原始日誌／SMART 保留在忽略的 `evidence/storage-2026-10-14/`，未公開。已獨立解碼 SMART 位元組，核對溫度與計數器，PowerShell 讀取程式也成功執行。標準儲存可靠度計數器不可用，ATA SMART 查詢遭拒，因此未另行更新驗證 Toshiba 目前的原始 SMART。後續硬體隔離需要實體操作；根因與長期修復效果仍未確認。
