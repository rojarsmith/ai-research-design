[English](README.md) | **繁體中文**

# PC 故障分析與解決辦法

查核日期：**2026-10-14**。英文為主要語言，另提供完整繁體中文對照。

以瀏覽器開啟[離線雙語查閱頁](dist/index.html)。預設英文；瀏覽器儲存可用時記住語言選擇，並支援搜尋與優先順序篩選。不需安裝或網路服務。其他 PC 症狀及證據蒐集請見[通用排查流程](research/workflow.zh-TW.md)。

新增個案：[裝置管理員：四個 Other devices 與 USB Port Reset Failed](research/device-manager-bluetooth-usb.zh-TW.md)。分開確認停用狀態、缺驅動與 USB 列舉失敗。

儲存個案：[Kingston 開機 SSD 從 BIOS 消失，斷電才恢復](cases/2026-10-14-kingston-nvme-dropout.zh-TW.md)。包含 51°C 與 91°C 欄位差異、唯讀 NVMe 實測、兩次 bugcheck 及實體交叉排查步驟；根因仍未確定。

## 截圖個案：2026-10-03

提供的 `Screenshot 2026-10-03 183937.png` 顯示 Administrative Events，共 **29,756 筆**。這不是崩潰次數，也不是本次事故的故障數。目前只有清單，缺少一般訊息、XML、EVTX、傾印、Windows 組建與硬體資料。根因**尚未確定**，並未在 PC 執行任何修復。

| 顯示的本機時間 | 可見觀察 | 判讀界線 |
| --- | --- | --- |
| 17:28 起 | 重複 DistributedCOM 10029／10016；17:33:29 有 Application Error 1000 | 可能是不同程式／服務問題，因果尚未建立 |
| 18:38:01／18:38:08 | volmgr 161／Kernel-Power 41 | 優先查可能的傾印失敗與非正常關機 |
| 18:38:19 | 三筆 Kernel-EventTracing 28 | 需要事件資料中的提供者 GUID 與狀態 |
| 18:38:26 | EventLog 6008、Eventlog 1101 及 DCOM | 讀取 6008 內記載的關機時間；若確認日誌遺失則調查 |
| 18:38:28–18:38:31 | CodexSandboxService 1003、CoworkVMService 1、AppModel-State、DCOM 與註冊警告 | 可能為開機後影響或獨立問題；先後順序不能證明因果 |

時間依截圖抄錄，時區偏移未知；清單部分列也未嚴格按時間排序。匯出後以 UTC 排序，區分事件記錄時間與 6008 內的關機時間。開機群組只是**假設**，不能證明全部事件都是同一崩潰的原因或結果。

## 建議順序

1. 保留日誌並確認症狀，用 6008 找出真正事故時間；不要清除證據。
2. 調查 41／6008，確認 161 的完整訊息及傾印設定。
3. 識別 1000 的執行檔，以及 10029、28、AppModel-State、1003、1 的確切目標，處理可重現的功能故障。
4. 將 10016 與 Microsoft 已記載模式比對，360 則依預期註冊／登入需求判斷；不以警告數歸零為目標。

## 事件處理表

優先順序為建議排查次序，不代表機率估計。下方區分已知一般行為與須比對完整訊息的條件解讀。來源支持相關技術／流程，不一定定義每個事件 ID。20／21／23／24 僅為方便調查而分組，仍須各別讀取結果。

### Kernel-Power — 41

**優先追查** · Critical · 追查非正常重新啟動

**意義:** Windows 偵測到未完整關機。事件 41 記錄結果，不能據此判定電源供應器故障或確認曾藍畫面。

**所需證據:** 完整 XML：BugcheckCode、BugcheckParameter1–4、PowerButtonTimestamp 與 SleepInProgress。另蒐集 WER-SystemErrorReporting 1001、WHEA-Logger，以及先前的儲存或顯示事件。

**步驟:**

1. 開啟事件 6008 找出上次關機時間，再查看該時間之前的事件；事件 41 的記錄時間可能屬於下一次開機。
2. BugcheckCode 非零時，將十進位轉為十六進位並分析對應傾印。若為零，仍可能是斷電、當機或未能記錄的崩潰。
3. 記錄當時負載與近期變更。一次測試一項可還原變更，例如恢復已知穩定的超頻／降壓設定，或在時間證據支持下回復驅動。檢查供電連接與溫度。

**驗證:** 重現原本負載並比較重啟頻率；僅一次重啟後沒有新事件不足以確認修復。

**避免:** 勿僅憑事件 41 就更換電源或修改 DCOM 權限。

**參考:** [Microsoft: Event 41 troubleshooting](https://learn.microsoft.com/en-us/troubleshoot/windows-client/performance/event-id-41-restart) · [Microsoft: Unexpected reboot investigation](https://learn.microsoft.com/en-us/troubleshoot/windows-server/performance/troubleshoot-unexpected-reboots-system-event-logs)

### volmgr — 161

**優先追查** · Error · 恢復可用的崩潰證據

**意義:** 常見解讀為崩潰傾印建立失敗，須確認這台 PC 的實際訊息與狀態資料；截圖並未顯示。缺少傾印不能判定是哪個元件導致崩潰。

**所需證據:** 一般訊息、裝置／磁碟區名稱、狀態或 BugCheckProgress（若有）；傾印設定、分頁檔設定、可用空間及既有傾印時間。

**步驟:**

1. 檢查「啟動及修復」→「寫入偵錯資訊」。一般排查可考慮「自動記憶體傾印」，Windows 磁碟區使用系統管理的分頁檔，並保留足夠空間。
2. 檢查 C:\Windows\MEMORY.DMP 與 C:\Windows\Minidump。變更前保留既有證據；蒐集工具只列出這些檔案資訊。
3. 若事故前持續出現儲存錯誤，先備份，再用製造商診斷檢查已識別的磁碟與控制器。即使設定正確，突然斷電仍可能無法產生傾印。

**驗證:** 自然再次發生崩潰後，確認有新的可讀傾印並檢查 161 是否重現；不要故意讓 PC 崩潰。

**避免:** 勿認定事件 161 證明 SSD 故障，也不要手動刪除分頁檔。

**參考:** [Microsoft: Automatic memory dump](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/automatic-memory-dump) · [Microsoft: Kernel dump types](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/varieties-of-kernel-mode-dump-files)

### EventLog — 6008

**優先追查** · Error · 找出真正的關機時間

**意義:** 上次關機非正常結束，可與事件 41 相互印證，但不代表另一個獨立根因。

**所需證據:** 「一般」內的關機日期／時間，以及事件本身不同的 TimeCreated。記錄 PC 時區。

**步驟:**

1. 使用訊息內的關機時間作為事故時間窗基準。
2. 比對 User32 1074、Kernel-General 開關機紀錄及 WER-SystemErrorReporting 1001。資訊層級事件也要保留。
3. 接續事件 41 的流程，不要把 6008 當作第二項硬體故障。

**驗證:** 根因解決後，正常關機／重啟應呈現預期的事件順序。

**避免:** 勿將事件記錄時間誤認為 PC 斷電時間。

**參考:** [Microsoft: Unexpected reboot investigation](https://learn.microsoft.com/en-us/troubleshoot/windows-server/performance/troubleshoot-unexpected-reboots-system-event-logs)

### Application Error — 1000

**有症狀時追查** · Error · 識別崩潰的應用程式

**意義:** 應用程式崩潰紀錄。可見的 17:33:29 紀錄約比重啟群組早一小時，尚未證明因果關係。

**所需證據:** 失敗的應用程式與模組名稱／路徑／版本、例外代碼、位移、處理程序 ID 及報告 ID；相符的 Windows Error Reporting 紀錄。

**步驟:**

1. 以 perfmon /rel 開啟可靠性監視器，比對程式與時間。
2. 單獨重現該程式的故障。更新或修復已識別的程式，或回復近期相關變更。
3. 若仍失敗，依官方方式蒐集個別應用程式的 WER 傾印。僅顯示 ntdll.dll 或 KERNELBASE.dll 出錯，不能證明根因在 Windows。

**驗證:** 重複相同操作，確認崩潰與對應 1000 紀錄不再持續發生。

**避免:** 尚未識別執行檔之前，不宜直接重裝 Windows。

**參考:** [Microsoft: Application/service crashes](https://learn.microsoft.com/en-us/troubleshoot/windows-server/performance/troubleshoot-application-service-crashing-behavior) · [Microsoft: Collecting user-mode dumps](https://learn.microsoft.com/en-us/windows/win32/wer/collecting-user-mode-dumps)

### DistributedCOM — 10029

**有症狀時追查** · Error · 先讀取訊息中的 COM 目標

**意義:** COM 啟用／服務問題只是待驗證假設。截圖無法識別 CLSID、服務或錯誤；此處沒有已確認的通用修法。

**所需證據:** 完整一般訊息／XML、CLSID 或類別名稱、服務名稱及 HRESULT／狀態。處理前先識別所屬軟體。

**步驟:**

1. 確認訊息是否真的描述啟用逾時，以及是否指向等待停止的服務。
2. 若訊息明確提到 AppCaptureManager／BcastDVRUserService 且錄影失敗，可測試錄影設定並修復／更新相關錄影程式。此為條件分支，不代表已識別這台 PC 的問題。
3. 其他目標應排查該程式／服務及其相依元件，比較正常運作與故障操作時的重現情況。

**驗證:** 已識別的操作可成功，且原本觸發條件下同一目標的錯誤不再重複。

**避免:** 勿套用事件 10016 的權限修改，也勿認定所有 10029 都是 Xbox／Game Bar。

尚未建立事件專屬的權威定義；步驟為建議診斷方法。

### Kernel-EventTracing — 28

**有症狀時追查** · Error · 識別追蹤提供者

**意義:** 此事件屬於 Windows 事件追蹤。若一般訊息指出設定提供者 traits 失敗，再排查該提供者與狀態。僅選取的清單列無法識別裝置或驅動。

**所需證據:** EventData 內的 ProviderGuid、ErrorCode、通道及執行脈絡。須區分發布此追蹤錯誤的 GUID 與事件資料內被點名的提供者 GUID。

**步驟:**

1. 複製一般訊息與 XML，比對三筆可見事件的提供者 GUID。
2. 若有註冊的提供者中繼資料，可用來查核；不要從網路上的 GUID 個案就認定是耳機、USB 控制器或 GPU。
3. 若對應裝置或程式也故障，更新／回復已識別元件並測試。若僅開機後追蹤失敗且無症狀，可在重啟問題處理後觀察。

**驗證:** 原本裝置／程式操作及追蹤註冊正常；正常開機後比較相同提供者與狀態。

**避免:** 勿停用追蹤通道來隱藏證據。

**參考:** [Microsoft: Event Tracing for Windows](https://learn.microsoft.com/en-us/windows/win32/etw/event-tracing-portal)

### Eventlog — 1101

**有症狀時追查** · Error · 確認是否遺失稽核紀錄

**意義:** 若實際訊息表示傳輸過程丟棄稽核事件，代表部分稽核證據缺失。須確認一般訊息、通道及原因碼；僅依截圖的判讀仍屬暫定。

**所需證據:** 完整訊息／XML、Reason（若有）、Security 日誌大小／保留方式，以及是否在沒有關機時也發生。

**步驟:**

1. 匯出事故時間窗內的 Security、System 與 Application；讀取 Security 可能需要系統管理員權限。
2. 恢復正常操作後，檢查遺失是否持續。若持續，排查重複的記錄失敗、容量與儲存問題。
3. 受管理 PC 若持續遺失稽核，應交由 IT 處理；政策及保留設定需依組織情境調整。

**驗證:** 在具代表性的正常操作期間，稽核遺失事件不再持續發生，且預期紀錄存在。

**避免:** 勿把清除 Security 日誌或停用稽核當作修法。

**參考:** [Microsoft: Get-WinEvent](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.diagnostics/get-winevent)

### AppModel-State — 20, 21, 23, 24

**有症狀時追查** · Warning · 檢查受影響的應用程式套件

**意義:** 這些紀錄需要套件名稱、操作與結果，可能描述應用狀態修復嘗試／結果；四個 ID 不一定代表四項獨立故障。

**所需證據:** 完整套件名稱、LocalSettings／SettingsInitialize 等操作、錯誤代碼及修復結果；開始功能表、搜尋或程式是否確實失敗。

**步驟:**

1. 先識別確切套件並重現症狀，再進行變更。
2. 優先使用該程式支援的「修復」。必要時備份本機資料後，僅重設／重裝已識別程式；重設可能清除設定。
3. 開始功能表／搜尋故障依官方排查流程處理，並用另一個測試使用者設定檔比較，確認是否僅影響原設定檔。

**驗證:** 受影響程式可正常使用，同一套件／操作不再持續進入失敗循環。

**避免:** 勿任意刪除 StateRepository 資料庫或全面重新註冊所有 AppX 套件。

**參考:** [Microsoft: Start menu troubleshooting](https://learn.microsoft.com/en-us/troubleshoot/windows-client/shell-experience/troubleshoot-start-menu-errors)

### CodexSandboxService.OpenAI.Codex — 1003

**有症狀時追查** · Error · 蒐集沙箱服務的完整錯誤

**意義:** 18:38:28 可見兩筆服務錯誤。查核的文件未能建立事件 1003 的確切定義或原因；與重啟時間接近只代表相關，不能證明因果。

**所需證據:** 一般訊息／XML、已安裝程式版本、失敗操作、處理程序／服務結束或狀態碼，以及正常開機後是否持續發生。

**步驟:**

1. 重現一個簡單沙箱操作並記錄完整錯誤；重啟程式前保留工作。
2. 檢查程式可用的更新及診斷功能。若可重現，透過受支援的安裝方式修復／更新所屬程式。
3. 保持沙箱安全控制啟用。聯絡產品支援時提供完整錯誤與重現步驟，不要認定該服務導致整台電腦重啟。

**驗證:** 正常開機後，原本失敗的沙箱操作可重複成功。

**避免:** 勿為了消除事件 1003 就授予廣泛權限或停用沙箱。

**參考:** [OpenAI: Windows sandbox](https://learn.chatgpt.com/docs/windows/windows-sandbox)

### CoworkVMService — 1

**有症狀時追查** · Warning · 識別 VM 服務所屬軟體

**意義:** 18:38:29 出現該服務的警告。截圖無法確認所屬軟體、事件意義及 VM 需求；名稱本身不足以證明特定廠商或虛擬化平台故障。

**所需證據:** 完整警告、執行檔路徑、發行者簽章、已安裝程式／版本、相依／狀態資訊，以及失敗的 VM 操作。

**步驟:**

1. 檢查服務執行檔與簽章以識別軟體，不要為了檢查而執行未知檔案。
2. 核對所屬程式需求及實際 VM 啟動錯誤；只有需求與錯誤指向時，才檢查虛擬化設定。
3. 正常開機後若 VM 操作仍失敗，修復／更新已識別程式；否則先在重啟問題解決後觀察。

**驗證:** 所屬程式的 VM 可啟動並完成原負載，沒有相同警告／故障。

**避免:** 勿僅憑服務名稱修改 Hyper-V、VBS 或 BIOS 虛擬化設定。

尚未建立事件專屬的權威定義；步驟為建議診斷方法。

### DistributedCOM — 10016

**比對後觀察** · Warning · 比對官方記載的可忽略模式

**意義:** Microsoft 記載了特定 DCOM 權限事件，由預期的重試行為產生。內容相符且功能正常時可不處理；這不代表所有 10016 都無害。

**所需證據:** CLSID、APPID、安全性脈絡／SID 及完整權限訊息，與 Microsoft 範例比對。

**步驟:**

1. 若訊息符合官方模式且元件正常，不需修復。
2. 若功能失敗或目標不同，使用完整訊息排查該元件。
3. 保留證據後可用自訂檢視改善閱讀；篩選只是改變顯示，不是修復根因。

**驗證:** 相關元件正常運作。對已知可忽略事件，警告數歸零不是修復標準。

**避免:** Microsoft 不建議僅為消除這些已記載事件而修改 DCOM 權限。

**參考:** [Microsoft: Documented DCOM 10016 pattern](https://learn.microsoft.com/en-us/troubleshoot/windows-client/application-management/event-10016-logged-when-accessing-dcom)

### User Device Registration — 360

**比對後觀察** · Warning · 確認是否需要企業佈建

**意義:** 若一般訊息指出 Windows Hello for Business 佈建不會啟動，應查看先決條件結果。未受管理的個人 PC 可能不需要企業佈建；不能因此認定個人 PIN 登入故障。

**所需證據:** 完整先決條件結果及實際登入症狀。受管理 PC 另需加入與政策狀態；dsregcmd /status 會包含識別資料。

**步驟:**

1. 登入正常且無企業註冊需求時，先觀察，不要強制佈建。
2. 需要企業佈建時，使用 dsregcmd /status 並與 IT 核對裝置加入、帳號、政策及其他先決條件。
3. 若個人 PIN／生物辨識登入失敗，應針對該症狀排查，不要自動歸因於企業註冊。

**驗證:** 預期的登入方式可正常使用；受管理 PC 則需完成預期佈建。

**避免:** 勿僅為消除警告就清除 TPM、刪除憑證或中斷組織帳號連線。

**參考:** [Microsoft: Windows Hello for Business prerequisites](https://learn.microsoft.com/en-us/windows/security/identity-protection/hello-for-business/hello-hybrid-cloud-kerberos-trust-provision) · [Microsoft: Business enrollment diagnostics](https://learn.microsoft.com/en-us/windows/security/identity-protection/hello-for-business/deploy/hybrid-cert-trust-enroll)

## 檔案與維護

[排查流程](research/workflow.zh-TW.md) · [個案範本](cases/case-template.zh-TW.md) · [Collector](scripts/Collect-Evidence.ps1)

成對事件內容修改 `data/events.json`，查核來源修改 `data/sources.json`。執行 `python scripts/build.py` 重建雙語報告與離線頁。流程與個案檔案需成對更新；原始證據存於忽略的 `evidence/`，勿提交可識別日誌／傾印。

## 已查核來源

- [Microsoft: Event 41 troubleshooting](https://learn.microsoft.com/en-us/troubleshoot/windows-client/performance/event-id-41-restart)
- [Microsoft: Unexpected reboot investigation](https://learn.microsoft.com/en-us/troubleshoot/windows-server/performance/troubleshoot-unexpected-reboots-system-event-logs)
- [Microsoft: Automatic memory dump](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/automatic-memory-dump)
- [Microsoft: Kernel dump types](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/varieties-of-kernel-mode-dump-files)
- [Microsoft: Documented DCOM 10016 pattern](https://learn.microsoft.com/en-us/troubleshoot/windows-client/application-management/event-10016-logged-when-accessing-dcom)
- [Microsoft: Application/service crashes](https://learn.microsoft.com/en-us/troubleshoot/windows-server/performance/troubleshoot-application-service-crashing-behavior)
- [Microsoft: Collecting user-mode dumps](https://learn.microsoft.com/en-us/windows/win32/wer/collecting-user-mode-dumps)
- [Microsoft: Event Tracing for Windows](https://learn.microsoft.com/en-us/windows/win32/etw/event-tracing-portal)
- [Microsoft: Start menu troubleshooting](https://learn.microsoft.com/en-us/troubleshoot/windows-client/shell-experience/troubleshoot-start-menu-errors)
- [Microsoft: Windows Hello for Business prerequisites](https://learn.microsoft.com/en-us/windows/security/identity-protection/hello-for-business/hello-hybrid-cloud-kerberos-trust-provision)
- [Microsoft: Business enrollment diagnostics](https://learn.microsoft.com/en-us/windows/security/identity-protection/hello-for-business/deploy/hybrid-cert-trust-enroll)
- [Microsoft: Get-WinEvent](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.diagnostics/get-winevent)
- [Microsoft: wevtutil](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/wevtutil)
- [Microsoft: DISM/SFC repair workflow](https://learn.microsoft.com/en-us/troubleshoot/windows-server/installing-updates-features-roles/fix-windows-update-errors)
- [OpenAI: Windows sandbox](https://learn.chatgpt.com/docs/windows/windows-sandbox)
