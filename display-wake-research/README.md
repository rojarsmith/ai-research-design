# Desktop dual-monitor wake research

Research checked: **2026-10-14**. The user has identified Acer ET322QK, ASUS VG289, and Philips FTV. Windows power state, driver version, ASUS suffix, and the full Philips model remain unknown; candidate causes are not confirmed findings.

Latest material: [online findings and model-specific investigation](research/01-online-findings.md), [complete Traditional Chinese report](research/01-online-findings.zh-TW.md), [20 first-party references and scope](research/02-sources.zh-TW.md), and [observation template](cases/observation-template.md). No PC settings were changed and no wake tests were performed.

Added: [community reports requiring monitor power/input operations](research/03-community-discussions.md), covering the same Acer model, a related ASUS variant, and RTX 5070 Ti reports. Recurring discussions do not establish failure rates or a shared cause.

## Priorities after identifying the displays

1. Confirm the Windows+P mode and whether both primary displays are enabled; compare with Philips HDMI disconnected at the GPU.
2. Inspect Acer input selection/Auto Source, then test Quick Start Mode separately. Faster startup is documented; a fix for this wake failure is not.
3. Inspect ASUS indicators and input. The VG289Q manual does not list DP/HDMI Deep Sleep; confirm the full suffix before applying it.
4. Compare the installed NVIDIA version with historical wake fixes 5089560 and 5806798/5635230. A matching failure on this PC is not established.

The linked research documents the evidence and applicability. The general power-state workflow follows below.

## Reported setup

One NVIDIA GeForce RTX 5070 Ti drives Acer ET322QK and ASUS VG289, one over HDMI and one over DP; the exact mapping is unconfirmed. Philips FTV is also connected to GPU HDMI and used through Windows+P. After a long absence, the two primary monitors often require their physical power buttons before the picture returns. Office desktop and laptop displays return from black on mouse movement. The desired behavior is reliable mouse wake; whether PC sleep is retained can be decided after isolating the failure.

## Initial assessment

First distinguish **display-off** from **PC sleep**. Windows configures these with separate timers. If the desktop sleeps, the mouse must wake the PC and the GPU and monitors must then re-establish both links. If Windows remains active but the monitors stay blank, investigate monitor deep sleep, input selection/signal detection, cables, and graphics-driver recovery.

The office machines may only turn off their panels, or successfully resume from sleep. Input-device and monitor settings can also differ. NVIDIA's standard connector list does not identify the actual board: some partner cards have two HDMI ports. Computing performance and port count do not diagnose wake behavior.

DP can expose a different monitor re-detection behavior after sleep. ASUS documents that on certain products Windows may treat a sleeping DP-connected monitor as disconnected and reconnect it on wake; manuals for some ASUS monitors recommend disabling DP/HDMI Deep Sleep if wake fails. This establishes a possible mechanism, not that the unspecified monitors use it.

## Troubleshooting order

### 1. Record whether the PC is awake during the failure

At the next blank screen, avoid pressing monitor power first. Check PC power light/fans, Caps Lock response, keyboard response, or audio. If the PC slept, check mouse/keyboard wake first. If the PC is active and only the panels are blank, prioritize signal recovery.

### 2. Compare with display-off and PC sleep disabled

Windows 11: **Settings → System → Power & battery → Screen, sleep & hibernate timeouts**. Keep the desired display-off timer and temporarily set PC sleep to **Never** as a short diagnostic. Microsoft lists the two timers separately. If mouse movement then reliably restores both screens, the original PC sleep/wake path or post-wake display reconnection is implicated, rather than display-off alone.

This diagnostic may increase power use and should not be mistaken for a confirmed permanent fix.

### 3. If the PC stayed awake

- Follow the actual model manual. For Acer, test input/source selection and Quick Start separately; for ASUS VG289Q, inspect indicators and input first. Test Deep Sleep only if the actual model provides it.
- Confirm Windows+P and Windows display settings enable both primary displays. Compare with Philips HDMI disconnected to investigate the third display's role.
- Isolate HDMI and DP individually, then swap GPU ports. Determine whether the fault follows a monitor, DP path, port, or only the dual-monitor setup.
- Connect directly to the GPU; temporarily remove KVMs, docks, adapters, or extenders. Try short, known-good cables if available.
- During a blank screen, **Win+Ctrl+Shift+B** asks Windows to reset the graphics driver. Microsoft notes a beep or screen flicker may indicate success. Treat this as a diagnostic/recovery action, not proof of a fix.

### 4. If the PC did sleep

- Check Windows sleep timeout and whether the mouse/keyboard is allowed to wake the PC in Device Manager. If needed, capture `powercfg /lastwake`, `powercfg /devicequery wake_armed`, and `powercfg /a` for interpretation.
- Update Windows, motherboard BIOS/chipset, and the official NVIDIA graphics driver. Record current versions and dates. Consider a driver rollback only if onset clearly followed an update, then compare.
- Do not apply NVIDIA's older DP firmware updater as a presumed fix: its supported-product list covers older GPU families and does not list RTX 5070 Ti. Its stated issue is blank screen/hang at boot, not this sleep-resume symptom.

## Current working judgment

Because both displays often need manual power-button intervention, shared factors deserve priority over an isolated monitor fault: PC sleep state, Windows timers, GPU restoration of two outputs, and common monitor deep-sleep/signal-detection behavior. This is a symptom-based troubleshooting order, not a probability estimate or diagnosis.

The smallest immediate experiment that resembles the office behavior is to retain the display-off timer and temporarily disable PC sleep; if the problem persists, inspect each monitor's Deep Sleep setting. Choose permanent settings based on overnight sleep, power use, and security needs.

## Information still needed

Root-cause analysis still needs Windows version, motherboard/BIOS, GPU board, driver, ASUS suffix, Philips model, exact port mapping, mouse connection, display modes, and power timeouts. Record PC state, display indicators, Windows+P mode, No Signal messages, and whether one monitor-power press or a full off/on cycle restores the picture.

## Sources

- Microsoft, [Windows 11 power settings](https://support.microsoft.com/en-us/windows/experience/power-battery/power-settings-in-windows-11) (separate screen-off and device-sleep timers)
- Microsoft, [Troubleshooting blank screens in Windows](https://support.microsoft.com/en-us/windows/hardware/display-graphics/troubleshooting-blank-screens-in-windows) (connection checks, Win+Ctrl+Shift+B, display-mode checks)
- NVIDIA, [GeForce RTX 5070 family specifications](https://www.nvidia.com/en-us/geforce/graphics-cards/50-series/rtx-5070-family/) (5070 Ti lists 3×DP and 1×HDMI)
- ASUS, [DP sleep and reconnection with multiple monitors](https://www.asus.com/us/support/faq/1044064/) (on covered models/scenarios, Windows may treat a sleeping DP display as disconnected; HDMI differs)
- ASUS, [Deep Sleep wake guidance](https://www.asus.com/sg/support/faq/1050272/) (covered displays suggest disabling DP/HDMI Deep Sleep when wake fails)
- NVIDIA, [DP 1.3/1.4 display firmware updater](https://www.nvidia.com/en-us/drivers/nv-uefi-update-x64/) (supported-product list does not include RTX 5070 Ti; described symptoms concern blank/hung boot)

Vendor-specific behavior establishes possible mechanisms. The primary display families are known, while exact variants, settings, and failure states still require comparison.
