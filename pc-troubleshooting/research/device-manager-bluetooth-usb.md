**English** | [繁體中文](device-manager-bluetooth-usb.zh-TW.md)

# Device Manager: Other devices and USB port-reset failure

Checked: **2026-10-12**. Case input: `Screenshot 2026-10-12 102507.png`. This is a screenshot-based investigation plan; no device settings or drivers were changed.

Update: an authorized [live device scan](../cases/2026-10-12-device-manager-live-scan.md) now identifies the disabled service endpoints and the failed USB hub path. Read that case for current facts; the screenshot-only interpretation below records the initial evidence boundary.

## What the screenshot establishes

| Visible item | Interpretation | What is still needed |
| --- | --- | --- |
| Bluetooth Peripheral Device | Generic friendly name; possibly a Bluetooth service node | Problem code, hardware/compatible IDs, parent and intended function |
| Redmi Buds6 | Name suggests a paired accessory; does not identify the failing profile | Same details, plus whether playback and microphone work |
| RFCOMM COM | Name suggests a Bluetooth serial/service endpoint | Hardware IDs/service UUID and whether serial communication is needed |
| WATCH | Friendly name alone does not establish brand, model or service | Parent, IDs and intended watch integration |
| Unknown USB Device (Port Reset Failed) | Explicit USB port-reset failure with a yellow warning symbol | Device status, location/parent, hardware IDs and connection path |

The four Other devices icons appear to include a downward-arrow overlay. **The user subsequently confirmed manually disabling them** after Windows Update and the product vendors' official resources did not resolve the original issue. Current disabled state does not establish the earlier failure code. Do not label all four as missing-driver failures. Multiple nodes can represent services of one accessory, rather than four faulty pieces of hardware. Windows uses identifiers and INF matching to load Bluetooth profile drivers. [Bluetooth driver stack](https://learn.microsoft.com/en-us/windows-hardware/drivers/bluetooth/using-the-bluetooth-driver-stack).

The screenshot does not prove that any of these devices caused the earlier Kernel-Power 41 restart. Multiple AMD/ASMedia controllers and Generic USB Hub entries are not, by count alone, evidence of a fault.

## Read the status before choosing a fix

Right-click each item → **Properties**:

1. **General → Device status**: copy the full message and code.
2. **Details → Hardware Ids**, **Compatible Ids**, **Parent**, and **Location paths**: copy the available values. Hardware IDs help Windows match a device to a driver; they are different from the friendly name. [Hardware IDs](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/hardware-ids).
3. **Driver**: record provider/version/date when available; **Events**: record installation/start failures.
4. Record Windows build, motherboard/PC model, Bluetooth adapter model and the actual missing function. The adapter cannot be identified from the displayed USB controller names.

| Confirmed code | Meaning and next step |
| --- | --- |
| 22 | Device disabled. If intentionally disabled and unused, leave it alone. If its function is wanted, enable that item and inspect the resulting state. Enabling does not itself install a missing driver. [Code 22](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/cm-prob-disabled) |
| 28 | Driver installation is incomplete/missing. Identify the hardware/service, then obtain a matching supported driver. [Code 28](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/cm-prob-failed-install) |
| 43 | Windows stopped the device following a reported failure. It does not distinguish device, connection and driver causes by itself. [Code 43](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/cm-prob-failed-post-start) |

These are **Device Manager problem codes**, not Event Viewer event IDs. The screenshot does not show the actual numeric codes.

Optional read-only inventory in Windows PowerShell:

```powershell
Get-PnpDevice -PresentOnly |
    Where-Object { $_.Status -ne 'OK' } |
    Format-List FriendlyName, Class, Status, InstanceId
```

This lists present non-OK devices but does not prove their cause or show every property needed above. Instance IDs can include Bluetooth addresses/serial numbers; redact those before public sharing. Do not publish the whole inventory unnecessarily.

## Bluetooth branch: fix the intended function

For this case, repeating automatic driver updates is not the next diagnostic step. First identify the endpoint/service IDs and determine whether playback, microphone or another required function actually fails. Do not enable all four simply to remove disabled markers. If a needed endpoint must be tested, enable only that endpoint and record its new problem code; Code 22 can mask the previous issue. The original problem code, exact Bluetooth adapter and installed driver versions remain unknown.

1. If Code 22 is confirmed, first determine why the item was disabled. Enable only the needed item; recheck its code. If unused, keeping it disabled is a legitimate choice.
2. For Code 28 or a reproducible Bluetooth failure, identify the **actual Bluetooth adapter** under Bluetooth and install its supported PC/motherboard/adapter vendor driver for the installed Windows version. A GPU driver or generic AMD chipset installer is not automatically the Bluetooth driver.
3. If a particular accessory still fails, remove **that pairing** in Settings → Bluetooth & devices and pair it again. Pairing removal interrupts that accessory; keep another input method available if it is your mouse/keyboard. Driver update and re-pairing are supported troubleshooting steps. [Microsoft Bluetooth troubleshooting](https://support.microsoft.com/en-us/windows/hardware/bluetooth/fix-bluetooth-problems-in-windows).
4. Test playback and microphone for Redmi Buds6, or the specifically intended function of WATCH/RFCOMM. A Bluetooth adapter driver cannot manufacture support for a vendor-specific accessory service. If normal functions work but an optional service lacks a supported Windows profile, leave that optional function unused or remove the unused pairing. Do not force an unrelated driver onto it. [Bluetooth device installation](https://learn.microsoft.com/en-us/windows-hardware/drivers/bluetooth/installing-a-bluetooth-device).

Success means the intended function works and required nodes have no continuing problem. Deleting a node that returns at the next pairing is not a lasting repair.

## USB branch: locate the failing connection

Port reset is part of USB enumeration. A reset timeout can produce an unknown USB device before Windows has usable vendor/product information. If IDs are `USB\UNKNOWN`, `USB\RESET_FAILURE` or zero/placeholder VID/PID, do not use them to guess a manufacturer. Microsoft's older USB case study explains the enumeration distinction; its Windows 7 trace-tool walkthrough is not a current universal fix. [USB enumeration case study](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/case-study--troubleshooting-an-unknown-usb-device-by-using-etw-and-netmon).

The following sequence is a proposed isolation method:

1. Save work. Unplug nonessential external USB devices **one at a time**, refreshing Device Manager after each removal. Safely eject storage before unplugging it. Retain needed keyboard/mouse access. Identify which disconnection removes the failed node.
2. For that device, bypass a hub/dock/front-panel connection and use a direct motherboard port where available. Try a known-good compatible data cable and another port. Change one variable per test.
3. Test the suspected device/cable on another PC and a known-good comparable device on the suspect port. Failure following a device/cable points there; failure shared by different devices on one path points toward the port/hub/controller path. Neither result alone proves a particular component is defective.
4. Shut down before power cycling. For a desktop, disconnect external power and separately powered hubs briefly, then reconnect and boot. For a laptop/internal battery, follow the manufacturer's power-reset procedure. Temporary recovery can identify a state issue but is not proof of a permanent fix.
5. If the problem remains, uninstall **only the identified failed Unknown USB Device entry**, leave any driver-package removal option unchecked, then reconnect it or scan for hardware changes/restart. If the physical reset failure persists, the warning will return. Do not uninstall all controllers or hubs.
6. If it remains after external peripherals are removed, inspect the connection tree/Location paths. Internal Bluetooth, a camera, card reader or another internal USB device is possible; the screenshot does not identify which. Use **View → Devices by connection** or Microsoft's [USBView](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/usbview), if needed. Failed enumeration may leave descriptions unavailable, but the topology can still help locate the port.
7. Once the model/path is known, check relevant OEM chipset/controller/device driver and firmware updates. A Microsoft-provided xHCI driver is normal and need not be replaced merely because its provider is Microsoft. [Windows USB host-side drivers](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/usb-3-0-driver-stack-architecture). Internal-cable isolation or firmware changes should follow the exact hardware's service guidance.

If failure occurs only after sleep/wake, document that trigger and investigate the identified device's power behavior. Do not disable USB selective suspend globally as the default remedy; Microsoft recommends keeping it enabled. [Selective suspend](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/usb-selective-suspend).

Verify several reconnects and the original workload; include sleep/wake only if it was the trigger. Record recurrence and port topology, not just whether the yellow symbol briefly vanished. If a device fails across PCs with known-good cables, seek device service; if failures stay on one PC/path, investigate that path before replacing accessories.

## Connection to the earlier restart case

Compare exact USB/Bluetooth failure timestamps with the **actual shutdown time inside 6008**, and with repeated trace-provider errors only after identifying their payload GUID. The presence of these devices and Kernel-EventTracing 28 does not establish a shared cause. Capture a reproducible failure and correlate it before assigning blame.

## Distinguishing software support from hardware instability

These are evidence-based directions, not a verdict assigning responsibility to a vendor or Microsoft:

| Controlled observation | Investigation direction |
| --- | --- |
| Required Bluetooth functions work; only an identified optional service has no matching supported profile/INF | Service support or driver matching; this alone is not evidence of unstable hardware |
| The same USB device fails on another PC with a known-good cable | Device hardware/firmware becomes more plausible; verify the other PC supports it |
| Failure follows one cable or hub and disappears with a known-good replacement | Cable/hub path becomes more plausible |
| Different known-good devices fail on one physical port/path but work elsewhere | PC port/hub/controller path; distinguish physical failure, firmware and driver behavior |
| Failure began with an identified driver/Windows change and reverses under a controlled rollback | Software regression becomes more plausible; retain versions and reproduction steps |
| Error remains after nonessential external devices are removed | Investigate internal USB topology; this does not by itself prove motherboard failure |

A manufacturer's driver failing to fix the problem does not prove Microsoft is responsible, and Windows Update finding nothing does not prove hardware is defective. Next needed evidence: actual playback/microphone behavior, USB status and hardware IDs, and whether the failed USB node remains without nonessential external peripherals.

[Return to the main report](../README.md) · [General workflow](workflow.md)
