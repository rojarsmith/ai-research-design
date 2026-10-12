**English** | [繁體中文](README.zh-TW.md)

# PC troubleshooting and solutions

Research checked: **2026-10-12**. Primary language: English; a full Traditional Chinese counterpart is available.

Open [the offline bilingual guide](dist/index.html) in a browser. It starts in English, remembers your language choice when browser storage is available, and offers search and priority filters. No installation or network service is needed. Read the [general troubleshooting workflow](research/workflow.md) for other PC symptoms and evidence collection.

## Screenshot case: 2026-10-03

The supplied `Screenshot 2026-10-03 183937.png` shows Administrative Events, with a total of **29,756 entries**. That count is neither a crash count nor a count of faults from this incident. We have the list only, not General, XML, EVTX, dumps, Windows build or hardware details. Root cause is **undetermined**. No repair was performed on the PC.

| Displayed local time | Visible observation | Interpretation boundary |
| --- | --- | --- |
| 17:28 onward | Repeated DistributedCOM 10029/10016; Application Error 1000 at 17:33:29 | May be separate app/service issues; no causal link established |
| 18:38:01 / 18:38:08 | volmgr 161 / Kernel-Power 41 | Investigate possible dump failure and unexpected shutdown first |
| 18:38:19 | Three Kernel-EventTracing 28 entries | Need the payload provider GUID and status |
| 18:38:26 | EventLog 6008 and Eventlog 1101, plus DCOM entries | Read 6008's embedded shutdown time; examine logging loss if confirmed |
| 18:38:28–18:38:31 | CodexSandboxService 1003, CoworkVMService 1, AppModel-State warnings, DCOM and registration warning | Could be startup aftermath or independent problems; chronology alone does not establish cause |

Times above are transcribed from the screenshot; its time-zone offset is unknown. The list is not strictly chronological in every row. Sort exported logs by UTC and distinguish recorded time from the shutdown time embedded in 6008. A startup cluster is a **hypothesis**, not proof that all these events caused or followed the same crash.

## Recommended order

1. Preserve the logs and confirm the user's symptom; determine the actual incident time using 6008. Do not clear evidence.
2. Investigate 41/6008 and verify 161's full message and dump configuration.
3. Identify the executable behind 1000 and the exact targets behind 10029, 28, AppModel-State, 1003 and 1. Investigate reproducible functionality failures.
4. Compare 10016 with Microsoft's documented pattern and 360 with the intended enrollment/sign-in behavior. Do not chase warning count as a repair objective.

## Event catalog

Priority is proposed triage order, not a probability estimate. Entries below distinguish established general behavior from conditional message interpretations. Linked references support the named technology/workflow; they do not necessarily define every event ID. IDs 20/21/23/24 are grouped only for investigation; inspect each result separately.

### Kernel-Power — 41

**Investigate first** · Critical · Investigate the unexpected restart

**Meaning:** Windows detected an incomplete shutdown. Event 41 records the outcome; it does not identify a faulty power supply or prove a blue screen.

**Evidence needed:** Full XML: BugcheckCode, BugcheckParameter1–4, PowerButtonTimestamp and SleepInProgress. Also collect WER-SystemErrorReporting 1001, WHEA-Logger and preceding storage or display events.

**Steps:**

1. Open Event 6008 to find the previous shutdown time, then inspect events before that time; the Event 41 logging time can belong to the next boot.
2. If BugcheckCode is nonzero, convert the decimal value to hexadecimal and analyze the matching dump. If zero, power loss, a hang or an unrecorded crash remain possible.
3. Record the workload and recent changes. Test one reversible change at a time: return overclock/undervolt settings to known stable values, or roll back a driver when timing supports it. Check power connections and temperatures.

**Verify:** Repeat the original workload and compare restart frequency. A quiet event list after one reboot is insufficient.

**Avoid:** Do not replace the PSU or change DCOM permissions based solely on Event 41.

**References:** [Microsoft: Event 41 troubleshooting](https://learn.microsoft.com/en-us/troubleshoot/windows-client/performance/event-id-41-restart) · [Microsoft: Unexpected reboot investigation](https://learn.microsoft.com/en-us/troubleshoot/windows-server/performance/troubleshoot-unexpected-reboots-system-event-logs)

### volmgr — 161

**Investigate first** · Error · Restore useful crash evidence

**Meaning:** A common interpretation is failed crash-dump creation. Confirm the actual message and status data on this PC; the screenshot does not show them. A missing dump does not identify the crashing component.

**Evidence needed:** General text, device/volume name, status or BugCheckProgress if present; dump settings, pagefile configuration, disk free space and existing dump timestamps.

**Steps:**

1. Check Startup and Recovery → Write debugging information. For normal troubleshooting, consider Automatic memory dump and a system-managed paging file on the Windows volume, with enough free space.
2. Check C:\Windows\MEMORY.DMP and C:\Windows\Minidump. Preserve existing evidence before changing settings; the collector only inventories these files.
3. If storage errors recur before the incident, back up data first, then check the identified disk and controller using manufacturer diagnostics. A hard power cut may still prevent a dump despite correct settings.

**Verify:** After a naturally recurring crash, confirm a new readable dump and inspect whether 161 recurs. Do not deliberately crash the PC.

**Avoid:** Do not assume Event 161 proves SSD failure or manually delete the pagefile.

**References:** [Microsoft: Automatic memory dump](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/automatic-memory-dump) · [Microsoft: Kernel dump types](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/varieties-of-kernel-mode-dump-files)

### EventLog — 6008

**Investigate first** · Error · Find the actual shutdown time

**Meaning:** The previous shutdown was unexpected. This corroborates Event 41 but does not add an independent root cause.

**Evidence needed:** The shutdown date/time inside General and the event's separate TimeCreated value. Record the PC time zone.

**Steps:**

1. Use the shutdown time embedded in the message to anchor the incident window.
2. Compare User32 1074, Kernel-General boot/shutdown entries and WER-SystemErrorReporting 1001. Preserve information-level entries as well as errors.
3. Continue with the Event 41 workflow instead of treating 6008 as a second hardware fault.

**Verify:** After the underlying problem is resolved, ordinary shutdown/restart cycles should have an expected shutdown sequence.

**Avoid:** Do not confuse the event logging time with the time the PC lost power.

**References:** [Microsoft: Unexpected reboot investigation](https://learn.microsoft.com/en-us/troubleshoot/windows-server/performance/troubleshoot-unexpected-reboots-system-event-logs)

### Application Error — 1000

**Investigate if symptomatic** · Error · Identify the application that crashed

**Meaning:** An application crash entry. The visible 17:33:29 entry is roughly an hour before the restart cluster; a causal link is unproven.

**Evidence needed:** Faulting application and module names/paths/versions, exception code, fault offset, process ID and report ID; matching Windows Error Reporting entries.

**Steps:**

1. Open Reliability Monitor with perfmon /rel and match the application and time.
2. Reproduce that application's failure separately. Update or repair the identified app, or roll back a recent relevant change.
3. If it still fails, collect an app-specific WER dump with the documented method. A fault in ntdll.dll or KERNELBASE.dll alone does not prove Windows itself is the cause.

**Verify:** Repeat the same app action and check that the crash and corresponding 1000 entries stop recurring.

**Avoid:** Do not reinstall Windows before identifying the executable.

**References:** [Microsoft: Application/service crashes](https://learn.microsoft.com/en-us/troubleshoot/windows-server/performance/troubleshoot-application-service-crashing-behavior) · [Microsoft: Collecting user-mode dumps](https://learn.microsoft.com/en-us/windows/win32/wer/collecting-user-mode-dumps)

### DistributedCOM — 10029

**Investigate if symptomatic** · Error · Read the named COM target first

**Meaning:** A COM activation/service problem is a working hypothesis. The screenshot does not identify the CLSID, service or error. No universal fix is established here.

**Evidence needed:** Full General/XML, CLSID or class name, service name and HRESULT/status. Identify the owning software before applying a remedy.

**Steps:**

1. Check whether the message actually reports an activation timeout and names a service waiting to stop.
2. If the message specifically names AppCaptureManager/BcastDVRUserService and capture fails, test recording settings and repair/update the relevant capture app. This is a conditional branch, not an identification of this PC's issue.
3. For other targets, troubleshoot that exact app/service and its dependencies. Compare recurrence during healthy operation and during the affected action.

**Verify:** The identified operation succeeds and the same target's error no longer repeats under the original trigger.

**Avoid:** Do not apply Event 10016 permission edits or assume every 10029 is Xbox/Game Bar.

Event-specific authoritative definition was not established; steps are proposed diagnostics.

### Kernel-EventTracing — 28

**Investigate if symptomatic** · Error · Identify the tracing provider

**Meaning:** This belongs to Event Tracing for Windows. If General reports an error setting provider traits, investigate that provider and status. The selected row alone cannot identify a device or driver.

**Evidence needed:** ProviderGuid in EventData, ErrorCode, channel and execution context. Distinguish the tracing event publisher's GUID from the provider GUID named in the payload.

**Steps:**

1. Copy General and XML. Compare provider GUIDs across the three visible entries.
2. Look up the named provider in registered provider metadata where available; do not infer a headset, USB controller or GPU from an online GUID anecdote.
3. If a matching device or app also fails, update/roll back that identified component and test. If tracing alone fails after boot without symptoms, monitor after the restart investigation.

**Verify:** The original device/app operation and tracing registration work; compare the same provider and status after a normal boot.

**Avoid:** Do not disable tracing channels to conceal evidence.

**References:** [Microsoft: Event Tracing for Windows](https://learn.microsoft.com/en-us/windows/win32/etw/event-tracing-portal)

### Eventlog — 1101

**Investigate if symptomatic** · Error · Check whether audit records were lost

**Meaning:** If the actual message says audit events were dropped by the transport, some audit evidence is missing. Confirm General, channel and reason code; a screenshot-only diagnosis is provisional.

**Evidence needed:** Full message/XML, Reason if present, Security log size/retention and whether it recurs without shutdowns.

**Steps:**

1. Export Security as well as System and Application for the incident window. Access to Security may need an elevated session.
2. After normal operation resumes, check whether loss persists. Investigate repeated logging failures, capacity and storage problems if it does.
3. On a managed PC, report continuing audit loss to IT; policy and retention changes require the organization's context.

**Verify:** Audit-loss events stop recurring during representative normal operation and the expected audit records are available.

**Avoid:** Do not clear the Security log or disable auditing as a fix.

**References:** [Microsoft: Get-WinEvent](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.diagnostics/get-winevent)

### AppModel-State — 20, 21, 23, 24

**Investigate if symptomatic** · Warning · Inspect the affected app package

**Meaning:** These entries need the package name, operation and result. They may describe app-state repair attempts/results; four IDs do not necessarily mean four unrelated faults.

**Evidence needed:** Package full name, operation such as LocalSettings/SettingsInitialize, error code and repair result; whether Start, Search or an app actually fails.

**Steps:**

1. Identify the exact package and reproduce its symptom before making changes.
2. Use the app's supported Repair option first. Reset/reinstall only the identified app if needed after preserving its local data; reset can erase settings.
3. For Start/Search failures, follow the official Start menu diagnostic workflow and compare a separate test user profile to isolate profile-specific behavior.

**Verify:** The affected app works and the same package/operation no longer produces a continuing failure loop.

**Avoid:** Do not delete StateRepository databases or re-register every AppX package indiscriminately.

**References:** [Microsoft: Start menu troubleshooting](https://learn.microsoft.com/en-us/troubleshoot/windows-client/shell-experience/troubleshoot-start-menu-errors)

### CodexSandboxService.OpenAI.Codex — 1003

**Investigate if symptomatic** · Error · Capture the sandbox service error

**Meaning:** Two service errors are visible at 18:38:28. The exact Event 1003 definition and failure cause are not established by the documentation checked. Their proximity to the restart is correlation only.

**Evidence needed:** General/XML, installed app version, failing action, process/service exit or status code, and whether the problem persists after a normal startup.

**Steps:**

1. Reproduce a small sandbox operation and record the exact failure; preserve work before restarting the app.
2. Inspect the app's available update and diagnostics controls. If reproducible, repair/update the owning app through its supported installation path.
3. Keep sandbox security controls enabled. Use the full error and reproduction when contacting product support; do not assume the service caused the system restart.

**Verify:** The previously failing sandbox operation succeeds repeatedly after normal startup.

**Avoid:** Do not grant broad permissions or disable the sandbox to silence Event 1003.

**References:** [OpenAI: Windows sandbox](https://learn.chatgpt.com/docs/windows/windows-sandbox)

### CoworkVMService — 1

**Investigate if symptomatic** · Warning · Identify the VM service owner

**Meaning:** A warning from a named service at 18:38:29. Ownership, event semantics and VM requirements are unknown from the screenshot; the name alone does not prove a specific vendor or hypervisor failure.

**Evidence needed:** Full warning, executable path, publisher signature, installed app/version, dependency/status information and the VM action that fails.

**Steps:**

1. Inspect the service's executable and signature to identify the installed software. Do not run an unknown executable just to inspect it.
2. Check the owning app's requirements and actual VM startup error. Check virtualization settings only if those requirements and the error indicate a need.
3. Repair/update the identified app if its VM operation fails after normal startup; otherwise monitor after resolving the restart.

**Verify:** The owning app's VM starts and completes the original workload without the same warning/failure.

**Avoid:** Do not change Hyper-V, VBS or BIOS virtualization settings based only on the service name.

Event-specific authoritative definition was not established; steps are proposed diagnostics.

### DistributedCOM — 10016

**Compare and monitor** · Warning · Check for the documented benign pattern

**Meaning:** Microsoft documents specific DCOM permission events generated by an expected retry pattern. Matching entries without a functional symptom can be left alone. This does not classify every 10016 as harmless.

**Evidence needed:** CLSID, APPID, security context/SID and the exact permission message; compare them with Microsoft's examples.

**Steps:**

1. If the message matches the documented pattern and the component works, take no repair action.
2. If functionality fails or the target differs, investigate that component using its full message.
3. For readability, use a custom view after preserving evidence; filtering changes the display, not the underlying fault.

**Verify:** The relevant component works. For documented benign events, eliminating the warning count is not a repair criterion.

**Avoid:** Microsoft advises against changing DCOM permissions merely to suppress these documented events.

**References:** [Microsoft: Documented DCOM 10016 pattern](https://learn.microsoft.com/en-us/troubleshoot/windows-client/application-management/event-10016-logged-when-accessing-dcom)

### User Device Registration — 360

**Compare and monitor** · Warning · Check whether business provisioning is expected

**Meaning:** If General says Windows Hello for Business provisioning will not launch, inspect prerequisite results. On an unmanaged personal PC, business provisioning may not be required. This is separate from assuming personal PIN sign-in is broken.

**Evidence needed:** Full prerequisite results and the actual sign-in symptom. For managed PCs, device join and policy state; dsregcmd /status output contains identifiers.

**Steps:**

1. If sign-in works and no business enrollment is intended, observe rather than forcing enrollment.
2. If business provisioning is required, check join/account/policy and other prerequisites with IT using dsregcmd /status.
3. If personal PIN/biometric sign-in fails, troubleshoot that specific symptom instead of treating business enrollment as the automatic cause.

**Verify:** The intended sign-in method works; on managed PCs, intended provisioning completes.

**Avoid:** Do not clear the TPM, delete credentials or disconnect an organization account merely to remove this warning.

**References:** [Microsoft: Windows Hello for Business prerequisites](https://learn.microsoft.com/en-us/windows/security/identity-protection/hello-for-business/hello-hybrid-cloud-kerberos-trust-provision) · [Microsoft: Business enrollment diagnostics](https://learn.microsoft.com/en-us/windows/security/identity-protection/hello-for-business/deploy/hybrid-cert-trust-enroll)

## Files and maintenance

[Workflow](research/workflow.md) · [Case template](cases/case-template.md) · [Collector](scripts/Collect-Evidence.ps1)

Edit `data/events.json` for paired event content and `data/sources.json` for checked references. Run `python scripts/build.py` to regenerate both reports and the offline page. Edit workflow and case files in matched language pairs. Raw evidence belongs in ignored `evidence/`; do not commit identifying logs/dumps.

## Checked references

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
