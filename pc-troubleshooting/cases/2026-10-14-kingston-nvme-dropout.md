**English** | [繁體中文](2026-10-14-kingston-nvme-dropout.zh-TW.md)

# Boot SSD disappears from BIOS after unexpected restarts

Checked **2026-10-14**, Asia/Taipei (UTC+08:00). Status: **cause unresolved; intermittent storage/controller/link failure is the priority hypothesis**. This case combines user observations, screenshots and authorized read-only queries. No repair, benchmark, firmware update or restart was performed.

## The observation that changes the investigation

The user reports two unexpected restarts this month. After each, **KINGSTON SFYRD2000G disappears from the BIOS NVMe/storage list as well as boot choices; removing power and restarting restores detection**. This is a device-enumeration failure before Windows starts. Boot Manager repair cannot explain that disappearance. Possible causes include a hung SSD controller/firmware, M.2 contact or PCIe link, motherboard or power delivery. It does not establish which component initiated the crash, or exclude RAM/PSU problems.

Live inventory confirms the Kingston is Disk 1, with **both the EFI system partition and Windows C:**. C:'s page file and configured small dumps also reside on it. The system uses Ryzen 7 7700 / ASUS PRIME X870-P, BIOS **1804**, and SSD firmware **EIFK31.7**. Disk numbers must be rechecked after hardware changes.

## Why the temperatures differ

| Reading | Evidence | Interpretation |
| --- | --- | --- |
| KSM Composite Temperature 51°C | Kingston SSD Manager 1.5.6.5 screenshot/live view | Matches the primary composite field |
| HWiNFO Drive Temperature 52°C | Screenshot, primary value varies around 50–56°C | A one-degree difference with different refresh times/rounding is unsurprising |
| HWiNFO Drive Temperature 3, fixed 91°C | Raw NVMe **temperature sensor 2 = 364 K**, approximately 90.85°C | Another drive-reported field; the label does not identify a third physical probe or prove current controller temperature |

Direct read-only queries returned composite **49.85–50.85°C**. HWiNFO's developer confirms its label maps to raw sensor 2. The exact physical/history meaning for **EIFK31.7** has not been established from a direct manufacturer specification. A stored peak or firmware-specific field is plausible, but remains an inference; do not call 91°C either a verified current hot spot or a harmless software mistake. See [HWiNFO's developer explanation](https://www.hwinfo.com/forum/threads/kingston-fury-renagade-not-showing-correct-temp.8836/).

There is separate evidence of **past high composite temperatures**: the drive reports 559 warning-temperature minutes and 14 critical-temperature minutes over its lifetime, with Identify Controller thresholds approximately **84°C / 89°C**. These counters have no incident timestamps, so they cannot connect overheating to either October crash. Kingston defines composite temperature as implementation-specific rather than necessarily one component's temperature. [Kingston SMART definitions](https://media.kingston.com/support/pdf/ssd-smart-attribute.pdf).

The same snapshot reports critical warning **0**, spare **100%**, percentage used **8%**, and media/data-integrity errors **0**. These do not exclude intermittent controller or connection failure. “92% life remaining” is an endurance estimate, not a 92% chance of reliability. Error-log count is **2,136**; the five returned nonempty recent entries decode to **Invalid Field in Command**, not bad sectors. This does not classify all earlier entries or identify the issuing application. [Microsoft status codes](https://learn.microsoft.com/en-us/windows/win32/api/nvme/ne-nvme-nvme_status_generic_command_codes).

## What Windows recorded

| Previous shutdown time inside Event 6008 | Next-boot Event 41 time | Bugcheck recorded in Event 41 |
| --- | --- | --- |
| Oct 3, 17:52:07 | Oct 3, 18:38:08 | Decimal 340 = **0x154 UNEXPECTED_STORE_EXCEPTION** |
| Oct 14, 15:34:47 | Oct 14, 17:54:57 | Decimal 30 = **0x1E KMODE_EXCEPTION_NOT_HANDLED**; parameter 1 = **0xC0000006 STATUS_IN_PAGE_ERROR** (sign-extended in XML) |

All times above are UTC+08:00. These are recorded shutdown times, not independently measured fault onset. 0x154 concerns the kernel memory store; it is not itself proof of a failed SSD. The second exception indicates an I/O failure bringing needed data into memory, but without a dump the responsible path/driver cannot be identified. [0x154](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/bug-check-0x154--unexpected-store-exception), [0x1E parameters](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/bug-check-0x1e--kmode-exception-not-handled), [NTSTATUS definition](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-erref/596a1078-e883-4972-9bbc-49e60bebca55).

Both boots also contain **volmgr 161 dump-creation failure**, referring to the volume currently mapped to C:. No existing memory/minidump was found. Loss of the boot disk could explain inability to write a dump, but this remains a hypothesis. The October query found no matching stornvme 129, disk 157 or WHEA 17–20; a failing boot disk might prevent logging, so absence does not clear it.

**A separate D: problem requires attention:** the Toshiba HDWN180 screenshot reports **8 pending sectors**. October logs contain **61 disk Event 7 records** for Harddisk0 and two Disk 0 retry events (153); the current Disk 0 is this Toshiba. Record count is not distinct bad-sector count, and historical disk numbering is not guaranteed. Do not use D: as the sole backup destination. This evidence does not prove it caused Kingston's BIOS disappearance.

## What the Toshiba's eight pending sectors mean

**Current Pending Sector Count (SMART 197 / C5)** counts sectors that the drive could not read reliably and has flagged for further evaluation. Eight sectors does not mean eight damaged files or 8% damage. A later successful read can clear a pending entry; confirmed defective sectors may be remapped to spare storage. Neither outcome guarantees recovery of the original data. [ULINK's SMART 197 definition](https://ulinktechda.zendesk.com/hc/en-us/articles/39980200495123-SMART-197-Current-Pending-Sectors-Count).

The value **8 is from the supplied HWiNFO screenshot**, not a fresh ATA SMART measurement. Together with the repeated disk bad-block records, it warrants protecting the data and planning replacement, but does not establish the affected files or a time until complete failure.

1. **Copy irreplaceable D: files to verified healthy storage first**, then confirm the backup files open. Pause new writes to D: while protecting the data; do not use either suspect drive as the only backup destination.
2. If copying stalls, reports read errors or the disk makes abnormal noises, avoid repeated retries. For important data without another copy, consider professional recovery rather than continuing experiments on the original disk.
3. **Do not start with `chkdsk /r`, formatting or a bad-sector repair utility before backup.** With I/O errors, preserve data first and perform recovery/repair on a copy where possible. [GNU ddrescue safety guidance](https://www.gnu.org/software/ddrescue/manual/ddrescue_manual.html).
4. After protecting the data, arrange replacement or a warranty assessment. For this drive's combination of pending sectors and repeated bad-block events, the recommendation is to retire it from important-data storage. A pending count returning to zero alone does not prove restored reliability.

This is a separate D: reliability issue; no causal link to Kingston disappearing from BIOS has been established. No backup, repair or replacement has been performed by this investigation.

## Isolation and improvement, in order

1. **Back up irreplaceable C: and D: data to verified healthy storage first.** C: currently uses about 1,492 GiB; E: is a 1 TB Crucial with about 525 GiB free, so it cannot hold a full clone of C:. Selected files may fit. No backup has been performed by this investigation.
2. **Record normal use without deliberately triggering another crash.** Log the varying composite temperature in HWiNFO. If the fault recurs naturally, photograph the BIOS NVMe list before removing power, note workload/time and whether a warm restart still fails. The fixed 91°C field alone is not a cooling test.
3. **After backup, shut down and unplug power before reseating.** Check the SSD connector, mounting screw, heatsink contact, pad protective film and airflow. Avoid bending the PCB; preserve the factory heat spreader/label. Improved cooling is useful if composite temperature rises abnormally, but improvement alone does not identify the failed component.
4. **Cross-test one variable at a time.** Move the Kingston to another compatible M.2 slot, then compare normal workloads over a meaningful period. If possible, test it in another PC's native NVMe slot and a known-good SSD in the original slot. A USB enclosure changes the connection and power path, so success there is weaker evidence. Failure following Kingston strengthens the SSD/RMA case; another SSD failing in the same original slot strengthens the motherboard/link/power-path case. One successful boot is insufficient.
5. **Check the exact board manual before moving drives.** PRIME X870-P M.2_4 shares resources with SATA6G_1/2; moving there can disable attached SATA devices. Logical PCIe paths do not establish the physical slot label. If Kingston is in a Gen5 slot, fixing that slot to Gen4 can be a later, reversible link test; save the old setting and change only that option. [ASUS manual](https://dlcdnets.asus.com/pub/ASUS/mb/SocketAM5/PRIME_X870-P/E23913_PRIME_X870-P_EM_WEB.pdf?model=PRIME+X870-P).
6. **Do not start with redundant updates or filesystem repair.** Installed BIOS 1804 matches ASUS's currently published latest release; installed EIFK31.7 matches the listed firmware for this model and KSM reports “No Firmware Update Available.” There is no verified newer applicable fix here. Do not force a different firmware branch, initialize/format C:, or run a heavy surface scan before backup. [ASUS BIOS](https://www.asus.com/motherboards-components/motherboards/prime/prime-x870-p/helpdesk_bios?model2Name=PRIME-X870-P), [Kingston firmware](https://www.kingston.com/en/support/technical/ksm-firmware-update).
7. **Open a Kingston support/warranty case now if practical.** Two BIOS-level disappearances requiring power removal justify escalation even with zero media errors. Include model/firmware, BIOS version, the two bugchecks, temperature history and BIOS photographs. Request interpretation of sensor 2 for EIFK31.7. Warranty eligibility still depends on purchase and terms. No vendor has been contacted on the user's behalf.

After backup, temporarily disconnecting the separately suspect Toshiba while powered off is another isolation test, since EFI/OS/pagefile are on Kingston. Check application/data dependencies first. Do not combine this with an M.2 move or cooling change if the aim is to identify the cause.

## Reusable read-only capture

[Read-NvmeHealth.ps1](../scripts/Read-NvmeHealth.ps1) checks model and NVMe bus before opening the disk, queries SMART and Identify Controller, and optionally reads the first eight error-log records through Windows storage-property queries. It does not reset, write to or update the SSD. [Microsoft API documentation](https://learn.microsoft.com/en-us/windows/win32/fileio/working-with-nvme-devices).

```powershell
# Recheck Get-Disk first; disk numbers can change. Run elevated if required.
.\scripts\Read-NvmeHealth.ps1 -DiskNumber 1 -ExpectedModel 'KINGSTON SFYRD2000G' -IncludeErrorLog
```

Local raw logs/SMART captures are retained in ignored `evidence/storage-2026-10-14/`, not published. SMART bytes were independently decoded to verify temperatures and counters; the PowerShell reader executed successfully. Standard storage reliability counters were unavailable, and ATA SMART queries were denied, so the Toshiba's raw current SMART was not independently refreshed. Further hardware isolation requires physical access. Root cause and lasting resolution remain unverified.
