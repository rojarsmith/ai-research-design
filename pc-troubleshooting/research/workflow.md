**English** | [繁體中文](workflow.zh-TW.md)

# PC troubleshooting workflow

Research checked: 2026-10-12. Scope: Windows PCs; this is a reusable investigation framework, not a diagnosis of the screenshot's machine.

## Start with the symptom

For Other devices or Unknown USB Device (Port Reset Failed), use the [Device Manager Bluetooth/USB case guide](device-manager-bluetooth-usb.md). Device Manager problem codes are separate from Event Viewer IDs.

| Symptom | Evidence to collect | First investigation | Success criterion |
| --- | --- | --- | --- |
| Blue screen or unexpected restart | Stop code, dump, full 41/6008/1001 events, workload, recent changes | Correlate the actual shutdown time with earlier driver/hardware events; analyze a matching dump | Original workload stable over a comparable observation period |
| Freeze requiring a power-button hold | Whether mouse/audio/network still respond; duration, temperatures, workload and preceding logs | Separate display-only failure from whole-system hang; test one implicated device/driver/change | Same trigger no longer hangs; forced shutdown is no longer needed |
| Black screen or display reset | Display connection, GPU/driver version, affected monitors, Display events and LiveKernelReports inventory | Test another cable/port, then a supported GPU driver change if evidence points there | Display remains usable under the same workload |
| Slow PC or high fan speed | Task Manager CPU/memory/disk activity, available space, startup apps and temperatures | Identify the process/resource bottleneck; measure before and after | Measured latency/resource use improves without lost functionality |
| Disk/I/O errors or missing files | Backup status, disk model/firmware, disk/controller events and health data | Preserve data before repair or intensive tests; inspect the identified device | Data accessible and integrity checked; recurring errors resolved |
| Network disconnects | Wi-Fi/Ethernet scope, adapter/driver, router behavior and whether other devices fail | Separate PC, LAN/router, DNS and ISP scope; test an alternate connection | Intended connectivity remains stable under the original trigger |
| USB/audio disconnects | Affected devices, hubs, ports, device events and reproducible action | Test one device without the hub, then another port/cable | Device completes the same task without disconnecting |
| App crash, broken Start/Search | Faulting executable/module, exception, package/operation, app version and report ID | Reproduce and repair the identified app; compare a test profile when relevant | Original action succeeds and the crash loop ends |
| Sleep/wake problem | Trigger (lid/sleep/hibernate), peripherals, driver versions, power events | Compare the same sleep/wake cycle with one implicated peripheral/change removed | Repeated cycles succeed without an unexpected restart |

These are proposed diagnostic branches. Do not infer a failing component from a single symptom or from event count.

## Preserve evidence before changing the machine

1. Record Windows edition/build (`winver`), PC/motherboard model, CPU/GPU/RAM, storage and power setup. Record app/driver/BIOS versions and what changed recently.
2. Record the symptom in plain language: what stopped working, what you were doing, whether a blue screen appeared, and whether you forced shutdown.
3. Record the device's time zone. Event Viewer usually displays local time; XML `SystemTime` is UTC. The screenshot does not establish its UTC offset.
4. Export System, Application and Security plus the relevant application/service channels for a bounded time window. Include information events: Administrative Events is a combined view, not a complete incident timeline.
5. Preserve full General and Details → XML for the relevant provider/ID pairs. Match on provider **and** ID. Include preceding events and normal-operation comparisons; an ID is not a globally unique diagnosis.
6. Inventory existing dump files. If analysis needs them, preserve them separately. Dumps and logs can contain usernames, paths, device/tenant identifiers or memory contents; review sharing destinations and keep raw evidence outside Git.

Use [Collect-Evidence.ps1](../scripts/Collect-Evidence.ps1) manually on the affected PC. It writes a new evidence folder only, queries a specified time window, retains XML and exports EVTX. It does not run repairs, clear logs, copy dump contents or upload anything. Security access may require an Administrator PowerShell. Missing/disabled channels and query/export failures are recorded in `manifest.json`; empty queries are marked `no-events`, not silently treated as failures or successes.

```powershell
# Choose explicit offsets matching the AFFECTED PC. +08:00 below is an example only.
# From this topic directory; does not relax execution policy.
.\scripts\Collect-Evidence.ps1 -Start '2026-10-03T17:20:00+08:00' -End '2026-10-03T18:50:00+08:00'
```

The screenshot's window is an initial candidate. Widen it if Event 6008 reports an earlier shutdown. Check the manifest before concluding there were no events. The browser guide displays research content and does not read the PC's logs automatically.

## Conditional repairs

First preserve evidence and identify the affected component. Apply one change at a time, record the previous setting/version and keep a rollback path. A reboot or app reset can interrupt work. App reset can erase local app data; export it first. Firmware changes require an exact model match and a stable machine. Do not flash BIOS simply to reduce warning counts.

If evidence indicates Windows component corruption or update failures, the documented repair order is an elevated terminal:

```powershell
DISM.exe /Online /Cleanup-Image /RestoreHealth
sfc.exe /scannow
```

These **change** Windows components and are separate from evidence collection. DISM may need a working update source or matching repair source. Save outputs and retest the symptom. They do not diagnose PSU/RAM/GPU faults, and are not a blanket cure for the screenshot. [Microsoft repair workflow](https://learn.microsoft.com/en-us/troubleshoot/windows-server/installing-updates-features-roles/fix-windows-update-errors).

For driver faults, identify the actual device and use its supported OEM/vendor package. If the issue started after a change, a controlled rollback can be informative. For hardware instability, compare stock settings and adequate cooling, then use the identified manufacturer's diagnostics. Back up a suspect drive before intensive testing. A passed memory/storage test does not rule out every intermittent fault. Escalate to repair when data loss, recurring hardware errors, overheating shutdowns or failure at known stable settings persists.

Avoid registry cleaners, indiscriminate permission edits, disabling audit/security features, mass AppX re-registration and unplanned Driver Verifier. A fix must improve the original symptom; merely hiding a warning is not verification.

## Record a case

Use [case-template.md](../cases/case-template.md), with its [Traditional Chinese equivalent](../cases/case-template.zh-TW.md). Store sanitized conclusions in a new case file; leave full raw evidence in ignored `evidence/`. Cite the source, distinguish observed facts from hypotheses, and record failed tests as well as successful ones. Apply the same evidence standard to every vendor, including EDT.

Compare a meaningful observation period and workload against the baseline. Record incident frequency, successful repetitions, new events and any remaining limitations. If the original trigger occurs only weekly, one clean day is not adequate confirmation.
