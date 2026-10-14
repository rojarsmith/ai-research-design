# LOXJIE A40 USB 爆音與斷聲研究

研究日期：2026-10-14，時區 Asia/Taipei。狀態：已完成本機唯讀盤點及網路案例整理；故障根因尚未確認。

你的症狀是電腦透過 USB 使用 LOXJIE A40，接雙聲道喇叭，不定期突然爆音後無聲，而且必須關開 A40 電源才能恢復。**最值得先驗證的是 USB 連接路徑與 A40 USB 音訊處理狀態；若故障當下連其他輸入也無聲，則提高擴大機保護、供電或內部硬體的調查優先度。** 關開電源同時重設許多元件，也會使 USB 重新連接，不能單憑恢復方式判定 A40 已壞或 Windows 驅動有錯。

目前有兩個具體可測線索：USB 音訊端點儲存格式為 **32-bit／384 kHz／雙聲道**；A40 的 USB 父節點是 **Generic USB Hub，再上接 ASMedia USB 控制器**。建議先將取樣率改為 48 kHz 單獨觀察，再改 USB 路徑，避免一次改多項而失去判斷依據。

## 本機查到的事實

完整採集時間為 2026-10-14 13:31 起，原始檔保存在 `evidence/20261014-133150-840/`，此目錄已排除 Git 追蹤。早先 `20261014-133001-321/` 為未完成採集，以完整採集為準。

| 項目 | 結果 | 對診斷的意義 |
| --- | --- | --- |
| 主機板 | ASUS PRIME X870-P，BIOS 1804 | 只記錄版本，不據此推斷 BIOS 有問題 |
| Windows | Windows 11 Pro N，10.0.26300 | 不從組建號推斷發行通道或故障原因 |
| USB 音訊裝置 | LOXJIE AUDIO，VID 152A／PID 880C，PnP 問題碼 0 | 採集當時裝置正常列舉，不代表串流全程正常 |
| 驅動 | XMOS 5.70.0.26310，驅動日期 2024-11-08，已簽章 | USB 主節點 oem168.inf；音訊子節點 oem165.inf，同版本 |
| 端點儲存格式 | 2 聲道，384000 Hz，32-bit container／32 valid bits | 由登錄的 DeviceFormat 二進位資料解析；不是故障當下實際串流量測 |
| 電源計畫 | Balanced；AC／DC 的 USB selective suspend 都啟用 | 啟用本身正常，不能當作故障證據 |
| XMOS 控制面板 | PageOptions 的 Visibility 已為 Visible | 不必照網路教學重改 XML；目前 Streaming 選值尚未取得 |
| 目前音訊查詢環境 | PnP AudioEndpoint 清單只出現 Remote Audio | 本次不能以該清單判定使用者本機的預設輸出或故障時輸出路由 |

DeviceFormat 對應共享模式的裝置格式；ASIO 或 WASAPI 獨佔模式可能使用其他格式。因此 384 kHz 是值得測試的已存設定，不是已證實的故障觸發條件。[Microsoft 格式屬性說明](https://learn.microsoft.com/en-us/windows/win32/coreaudio/pkey-audioengine-deviceformat)、[WAVEFORMATEX 欄位](https://learn.microsoft.com/en-us/windows/win32/api/mmeapi/ns-mmeapi-waveformatex)。

### USB 路徑與另一個錯誤裝置

```text
LOXJIE AUDIO（問題碼 0）
  └─ Generic USB Hub（VID 05E3／PID 0610，問題碼 0）
      └─ USB Root Hub
          └─ ASMedia USB 3.20 xHCI（VEN 1B21／DEV 2426，問題碼 0）

Unknown USB Device Port Reset Failed（問題碼 43）
  └─ 另一個 USB Root Hub
      └─ AMD USB 3.10 xHCI（VEN 1022／DEV 15B7，問題碼 0）
```

A40 邏輯位置是 `Port_#0004.Hub_#0006`；另一個錯誤裝置是 `Port_#0004.Hub_#0003`。**不是同一條 USB 控制器路徑，不能把 Code 43 當作 A40 斷聲的證據。** Hub 可能內建於某個裝置或板上，也可能是外接 Hub／螢幕／擴充座；僅憑 PnP 不能確認其實體外殼，也不能把邏輯 Port 4 當作後面板第 4 孔。先前另一份[USB 個案](../pc-troubleshooting/cases/2026-10-12-device-manager-live-scan.zh-TW.md)可作背景。

### 事件紀錄能說明的範圍

採集以近七日為查詢條件，System 最多讀取 12000 筆、Application 與各指定專用日誌最多 5000 筆再篩選，並非完整 ETW 追蹤。

- System 篩選結果有 48 筆 Kernel-Power 566，以及 USB 智慧卡讀卡機驅動 WudfUsbccidDriver 的 705 筆事件 7、事件 104／105 各一筆。讀卡機錯誤不能歸因到 A40。
- 篩選結果沒有含 LOXJIE、XMOS、VID_152A 或 tusbaudio 的 System 訊息，也沒有符合條件的音訊程式崩潰訊息。
- Audio Operational 有 1297 筆資訊事件，包括 1225 筆裝置狀態變更事件 65。沒有故障發生時間與端點對照，不能把這些變更叫作 A40 異常。
- 指定的 USBXHCI 及 PnP 日誌在查詢條件下沒有命中；Audio GlitchDetection 原本未啟用。

因此目前沒有「爆音當下 USB 重設」或「A40 驅動崩潰」的直接證據；日誌沒有命中也不能排除裝置韌體卡住、資料串流異常或類比功率級問題。

## 網路資料與你的症狀是否相符

官方產品資料指出 A40 使用 XMOS XU-316，支援最高 PCM 32-bit／768 kHz，並標示過熱與過流保護。因此 384 kHz 未超過標示能力；降低取樣率是隔離變因的測試，並非宣稱超規。[LOXJIE A40 官方產品頁](https://loxjie-audio.com/productshow.asp?id=161)。

| 第一手使用者案例 | 回報現象與處理 | 與本案的差異 |
| --- | --- | --- |
| [A40 討論串中的 USB 留言](https://www.reddit.com/r/BudgetAudiophile/comments/1cl5u3o/) | USB 播放開頭約一秒遺失；留言者表示調整 XMOS 選項解決 | 不是播放中爆音後持續無聲；只能支持調查串流啟停 |
| [A40 LDAC 問題，2024-07-14](https://www.reddit.com/r/BudgetAudiophile/comments/1e36fjo/) | 藍牙閒置約 15 分鐘後爆音／卡頓；停用 LDAC 改善，重開機暫時恢復 | 相同型號且有爆音及重開機線索，但輸入是藍牙，不能直接套用 USB 結論 |
| [A40 電腦 USB 低音喇叭嗡聲，2025-02-20](https://www.reddit.com/r/BudgetAudiophile/comments/1iu86it/) | 滑鼠操作伴隨嗡聲，發文者回報改光纖後消失 | 主要是持續干擾，並非爆音後鎖住；不能據此認定本案為接地迴路 |
| [A40 音量門檻斷聲，2025-07-20](https://www.reddit.com/r/BudgetAudiophile/comments/1m4iake/) | 藍牙輸入，音量 19 尚有聲、到 20 出現 click 後無聲 | 有音量相關斷聲，但沒有工程檢測或確定根因；你的發生音量尚未知 |

以上是個人回報，沒有故障率分母或受控維修結論。此次沒有找到足以確認「A40 USB 隨機爆音後必須重開電源」為單一已知通病、且有官方修復公告的證據。搜尋時已排除 Astro A40 耳機與 Soundcore Space A40 等同名產品。

### 驅動與 Always On 的限制

你已安裝 XMOS 驅動，不能把安裝驅動當作從零開始的解法。[XMOS 官方](https://www.xmos.com/software/usb-audio/driver-support/)要求第三方成品的驅動向成品供應商取得；其評估版有功能限制，不適合作為 A40 替代驅動。

[SABAJ 下載頁](https://sabaj.com.cn/pages/download)列有標示 2025-12-02 的 Loxjie USB Driver，及 v5.74.0 等歷史版本；這是後續向 LOXJIE 核實套件的線索。此次未驗證安裝檔的 INF 是否包含本機 VID／PID、簽章與 A40 版本相容性，也未取得針對此症狀的修復說明，不能宣稱更新一定有效。Windows 驅動更新與 A40 內部韌體更新是兩件事，不使用其他品牌或近似型號韌體。

A40 USB 留言連到 [ASR 的 XMOS 串流啟停討論](https://www.audiosciencereview.com/forum/index.php?threads/xmos-driver-settings-for-no-cutoff-delay.25838/)。此次該 ASR 網址開啟後回傳論壇首頁，未把未讀到的全文當作已核實操作指南。你本機 `XMOSUSBDACCpl.xml` 的 Options 已顯示；若控制面板提供 Streaming／Always On，可在確認原值後做單項測試。**介面已顯示不代表 Always On 已啟用。** 此測試主要針對閒置與啟停，不能代替硬體排查。

## 可能原因與判別條件

下表是排查優先序，不是統計機率。

| 優先度 | 工作假設 | 支持線索 | 最有區別力的下一步 |
| --- | --- | --- | --- |
| 高 | USB 路徑、Hub 或主機控制器與 A40 的互動 | 已確認經 Hub 接 ASMedia；故障後需重新初始化 | 以相同線材與音訊設定改到另一個控制器路徑，重新採集確認 |
| 高 | A40 USB 接收／韌體／驅動串流狀態異常 | 關開 A40 才恢復符合需重設的狀態，但尚無故障日誌 | 故障時保留 A40 電源，先測其他輸入；另用不同電腦直連 |
| 中高 | 高取樣率或格式切換的相容性問題 | 儲存的共享模式是 384 kHz | 先固定為 32-bit／48 kHz，如無此選項則 24-bit／48 kHz，觀察原場景 |
| 中 | 擴大機過熱、過流、電源或輸出級問題 | 接被動喇叭的功率路徑需要檢查；官方標示有保護 | 看其他輸入是否同時失效，以及與音量、低頻、使用時間的關係 |
| 條件式 | 閒置、USB 電源管理或 XMOS 串流停止後恢復失敗 | selective suspend 啟用；網友有啟停案例 | 先確認是否閒置後觸發，再測 Always On；不預設全面關省電 |
| 較後 | 單一播放程式、音效處理、DPC 排程或系統負載 | 尚無特定軟體／負載線索 | 固定格式、另一播放器對照；必要時再作時序追蹤 |

Microsoft 將音效增強、格式與驅動列為 Windows 爆裂音的排查項目；這提供一般排查依據，沒有證明 A40 的原因。[Microsoft 爆裂音指引](https://support.microsoft.com/en-us/windows/hardware/audio/fix-distorted-or-crackling-audio-in-windows)。

## 建議實測順序

### 先建立低風險的基準

因為已發生突然爆音，測試時把 A40 音量調低，使用一般內容，不用大音量、低頻掃描或戴耳機刻意重現。若反覆大爆音、異味或異常發熱，停止通電測試並走售後。檢查喇叭端子有無散股碰到相鄰端子時先關機，勿拆機。

1. 記下 A40 音量、喇叭型號、USB 線與連接位置。Windows「設定 → 系統 → 音效」選 **LOXJIE AUDIO 的 USB 端點**，不要選藍牙 LOXJIE A40 或 Remote Audio。
2. 先只把共享模式取樣率由 384 kHz 改為 **48 kHz**，能保持 32-bit 就保持；若只提供 24-bit／48 kHz，記錄兩項一起改變。若播放器使用 ASIO／獨佔模式，必須在播放器內確認實際輸出也是 48 kHz。
3. 在原本使用方式下觀察至少超過平常故障間隔；目前頻率未知，可先以數次日常工作時段或 2–3 天為起點。短時間沒發生只能記為尚未復現，不能寫已修好。
4. 若仍發生，保留上述格式，改接電腦另一個 USB 路徑，優先避開外接 Hub／螢幕／擴充座／KVM。執行採集腳本，確認是否真正離開目前 ASMedia／Hub 路徑；換孔不一定換控制器。
5. 路徑測試仍無改善，再單獨換已知良好的短 USB 資料線。對照相同輸出音量、內容與觀察時數。

### 下次斷聲時先保留能分辨原因的資訊

安全與音量控制優先；不需為蒐證維持危險的異常輸出。

1. 記錄台灣時間到分鐘、是否連續播放或剛恢復播放、A40 顯示輸入與取樣率、旋鈕／遙控是否有反應。不要因無聲而提高音量。
2. 音量調低後，若現有設備方便，**在不重開 A40 的情況下**切到手機藍牙或其他獨立輸入，確認是否能播放。切換本身也可能重設內部狀態，結果須如實記錄。
3. 其他輸入有聲、USB 無聲：優先查 USB／驅動／USB 韌體；不直接斷言功率級完全正常。
4. 所有輸入都無聲：提高 A40 共用處理、靜音／輸出設定、保護、供電及功率級的優先度。
5. 有餘裕時先執行採集，再試關閉重開播放器、拔插「A40 自己的 USB 線」，最後才關開 A40。只記真正試過的動作；目前使用者只確認需要關開電源，未取得各恢復方式的獨立對照紀錄。

### 第二輪才做的設定與交叉測試

- 若集中在閒置後，檢查 XMOS 控制面板 Options 的 Streaming 原值；有 Always On 時以它做單項比較。不要再編輯本機已顯示選項的 XML。
- 音效增強、空間音效與獨佔模式逐項比較並記錄原值。ASIO 緩衝大小只在確實使用 ASIO 的程式中有診斷意義，不是 YouTube 的通用解法。
- USB selective suspend 不列為第一步永久關閉項。Microsoft 明確建議保持啟用；若前面證據集中在閒置恢復，再作短期、可還原的 A/B 測試。[Microsoft 說明](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/usb-selective-suspend)。
- 用另一台電腦、良好線材直連 A40，維持相同喇叭與低音量。若故障跟著 A40，尤其其他輸入也受影響，售後檢測的價值高於反覆改 Windows。
- 若手邊已有光纖來源，用雙聲道 PCM 接 A40 做對照。改善可把範圍縮到 USB 支路與電氣連接，仍不能單獨證明是接地問題。現階段不必先買轉接器。

## 工具與紀錄

- [唯讀證據採集腳本](scripts/Collect-A40Evidence.ps1)：保存系統、驅動、USB 父節點、已開啟日誌、音訊端點與電源設定；不播放聲音、不重啟音訊、不改設定、不安裝驅動、不啟用追蹤。
- [故障紀錄模板](cases/observation-template.zh-TW.md)：記錄單次事件及每項對照測試。
- [來源索引](research/sources.zh-TW.md)：區分官方功能、使用者回報和本案推論。

在 PowerShell 執行；遇到存取拒絕時以系統管理員身分重試：

```powershell
& 'C:\my\build\github\ai-research-design\loxjie-a40-usb-research\scripts\Collect-A40Evidence.ps1'
```

每次輸出到新的時間戳目錄。原始資料包含裝置 ID 與部分系統事件，對外送修時可只提供必要摘要。這次採集未修改電源計畫、音訊格式、驅動或 A40 狀態。

## 何時交給售後

如果在另一台電腦、良好線材、48 kHz 及低音量仍能重現，或 USB 以外的獨立輸入也會爆音斷聲，應提供結果給經銷商／LOXJIE，要求依機身版本確認韌體與硬體檢測。可附上以下摘要，尚未執行的測試保留為待測，不填成已排除：

> LOXJIE A40 以 USB 接電腦、輸出到雙聲道喇叭，不定期爆音後持續無聲，需要關開 A40 電源恢復。目前 Windows 11 Pro N build 26300，XMOS 驅動 5.70.0.26310，USB VID 152A／PID 880C。原共享格式儲存為 32-bit／384 kHz；USB 路徑經 Hub 接 ASMedia 控制器。請確認本機版本是否有針對 USB 爆音／斷聲的已知問題、相容驅動或韌體，以及送修流程。48 kHz、不同控制器路徑、另一台電腦與其他輸入的測試结果待補。
