# Online findings and model-specific wake investigation

Checked on 2026-10-14. Public-source research only; no changes or reproduction tests have been performed on the affected PC. The [Traditional Chinese report](01-online-findings.zh-TW.md) contains the complete workflow; the [source register](02-sources.zh-TW.md) records scope and access limitations.

## Updated setup

The user identifies Acer ET322QK and ASUS VG289 as the two primary displays, one HDMI and one DP. A Philips FTV is also connected to the GPU over HDMI, with Windows+P used to switch display modes. The exact Acer/ASUS port mapping, ASUS suffix, Philips model, and GPU board model remain unknown. No hardware HDMI switch is established.

GPU boards can vary in physical outputs: an ASUS TUF RTX 5070 Ti officially has two HDMI ports. This illustrates why the NVIDIA standard connector count cannot establish the user's actual wiring; it does not identify their board. [ASUS specifications](https://www.asus.com/ro/motherboards-components/graphics-cards/tuf-gaming/tuf-rtx5070ti-16g-gaming/techspec/)

## Findings that change the troubleshooting order

- **Acer ET322QK:** the official manual describes signal-based recovery from power saving and lists Input, Auto Source, DP Format, and Quick Start Mode. Try fixed input/source selection first, then Quick Start separately. The latter is documented for faster startup, not as a confirmed wake fix. [Acer manual](https://global-download.acer.com/GDFiles/Document/User%20Manual/User%20Manual_Acer_1.0_A_A.pdf?acerid=637467234446678758)
- **ASUS VG289Q:** the inspected manual lists white for on, amber for standby, a Power Indicator option, and ECO Mode. It does not list DP/HDMI Deep Sleep. Confirm the suffix before applying this manual. Enable the indicator and inspect input selection; ECO is not established as the cause. [ASUS manual](https://dlcdnets.asus.com/pub/ASUS/LCD%20Monitors/VG289Q/ASUS_VG289Q_English.pdf)
- **Philips and Windows+P:** projection modes affect which displays receive output. Identify each display in Windows and record the active mode. Temporarily unplug Philips HDMI at the GPU, retaining other settings, to compare two-display operation with the three-device configuration. This is a proposed isolation experiment, not evidence of a Philips defect. [Microsoft multiple-display guide](https://support.microsoft.com/en-us/windows/hardware/display-graphics/how-to-use-multiple-monitors-in-windows)
- **HDMI can also fail to wake:** Dell documents four Alienware models requiring OSD/power input after HDMI deep sleep. None is the user's named primary monitor; the case establishes a possible failure type. [Dell article](https://www.dell.com/support/kbdoc/en-us/000202876/gsync-r4-models-connected-with-hdmi-deep-sleep-mode-wake-up-fails)
- **Driver recovery deserves investigation:** NVIDIA's Studio 572.60 history lists extended-display-sleep wake instability, issue 5089560. The official 610.52 hotfix announcement lists monitor wake failures, issues 5806798/5635230, also listed in 610.62. These are historical fixes, not a claim about the latest version or proof that this PC has the same fault. Compare the installed version and onset date. [NVIDIA Studio history](https://www.nvidia.com/Download/processFind.aspx?dtcid=1&lang=en-us&lid=1&osid=57&pfid=930&whql=4), [NVIDIA staff announcement](https://www.nvidia.com/en-us/geforce/forums/game-ready-drivers/13/586981/announcing-geforce-hotfix-driver-61052-released-68/3612710/)

Some NVIDIA dynamic pages expose only a JavaScript prompt when opened directly; the described entries were checked in indexed official content. Full internal bug analysis and a matching affected-monitor list were not available.

## Proposed sequence

1. Record power indicators, No Signal messages, whether one press or a full off/on cycle is needed, and whether mouse clicks/keyboard input work when movement does not.
2. Confirm Windows has enabled both primary monitors in the intended projection mode. Returning to that mode alone is a useful diagnostic result.
3. Remove Philips HDMI at the GPU for a long-idle comparison, keeping the other settings identical.
4. Separately compare display-off with PC sleep temporarily disabled. This isolates the sleep-resume path; retaining PC sleep may still be compatible with the user's preference once the failure is resolved.
5. Test Acer source selection and Quick Start individually, then single-display and cable/interface comparisons.
6. Record the installed NVIDIA version before one targeted update or evidence-based rollback. Do not update unrelated firmware simultaneously.

Compare repeated attempts and the original long absence duration. A successful short wake is insufficient to show that the issue is fixed.

## Windows input and evidence

Screen-off, S3 sleep, Modern Standby, and hibernation have different recovery paths. Use `powercfg /a` to identify supported states. In Modern Standby, mouse-button wake is documented; Bluetooth movement wake is optional. Click-versus-movement results can therefore be informative. Do not infer the sleep model solely from desktop versus laptop form factor. [Microsoft wake sources](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/modern-standby-wake-sources)

Read-only commands for the affected PC:

```powershell
powercfg /a
powercfg /getactivescheme
powercfg /query
powercfg /devicequery wake_armed
powercfg /devicequery wake_programmable
powercfg /lastwake
```

Available states do not prove the last state entered. Wake-armed devices may still have a failing hardware path, and lastwake does not record every display-only wake. System sleep diagnostics can supplement event records; SleepStudy is for Modern Standby systems. [Microsoft powercfg reference](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/powercfg-command-line-options)

Avoid treating blanket USB suspend disabling, maximum-performance GPU mode, Fast Startup changes, or DDC/CI toggling as established fixes. Microsoft recommends retaining USB selective suspend. Fast Startup concerns the shutdown/startup path. Record evidence before replacing hardware or applying firmware. [Microsoft USB guidance](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/usb-selective-suspend)
