**English** | [繁體中文](2026-10-12-device-manager-live-scan.zh-TW.md)

# Case 002: Bluetooth service nodes and USB hub reset failure

Status: **investigating; device topology identified, physical cause unconfirmed**.

Evidence collected on 2026-10-12; initial live snapshot at 10:36:40 UTC+08:00. The user authorized reading the PC's device inventory. Reads used `Get-PnpDevice`, `Get-PnpDeviceProperty`, CIM model/build queries and `pnputil /enum-devices ... /drivers`. Historical USB records were queried for the failing logical path. No devices were enabled/disabled, no drivers were installed/removed, and no restart or unplug operation was performed by the agent. Bluetooth addresses and full instance IDs are omitted from this report.

## User observations

- The four Other devices entries were manually disabled after Windows Update and product-vendor resources did not resolve the original issue.
- Redmi Buds6 playback and microphone are working.
- The user reports the USB error disappears upon unplugging, but did not identify the unplugged device or connection. At the time of follow-up, the user was away from the PC; no controlled physical test was performed.
- During the authorized live scan, the Unknown USB Device was still present. This does not contradict the user's report about a previous unplug test.

## Machine and functioning nodes

- Motherboard: ASUS PRIME X870-P, as reported by CIM; do not substitute the WIFI variant's support package.
- OS: Windows 11 Pro N; reported build 26300. This report does not infer release channel or blame the OS build.
- Radio: Realtek Bluetooth 5.3 Adapter, hardware ID `USB\VID_0BDA&PID_A729`, driver `1.9.1051.3002`, status OK / problem code 0.
- Redmi audio playback (`BthA2dp`), Hands-Free audio (`BthHFAud`), Hands-Free AG and AVRCP transport nodes reported OK / code 0. The user separately confirmed playback and microphone operation.
- The Bluetooth radio is under a working Generic USB Hub `VID_0BDA&PID_5411` on the AMD controller's logical root-port-2 path, then downstream port 2. The failed USB node is on that controller's root-port-4 path. Sharing a host controller does not establish a shared fault.

## What the four Other devices actually represent

Remote-device mappings below were derived by comparing each BTHENUM service instance's remote-address token with its remote device record. The addresses themselves are omitted.

| Visible name | Mapped accessory | Service UUID | Live problem code | Interpretation |
| --- | --- | --- | --- | --- |
| Bluetooth Peripheral Device | LOXJIE A40 | `0000180f-0000-1000-8000-00805f9b34fb` | 22 | Advertised Battery Service UUID; this does not prove the amplifier contains a battery or explain why it advertises this service |
| Redmi Buds6 | Redmi Buds 6 | `0000fd2d-0000-1000-8000-00805f9b34fb` | 22 | Additional service endpoint, separate from the working audio endpoints; exact function not established here |
| RFCOMM COM | Redmi Buds 6 | `df21fe2c-2515-4fdb-8886-f12c4d67927c` | 22 | Matches Google's Fast Pair message-stream RFCOMM UUID |
| WATCH | Redmi Buds 6 | `99999999-9999-9999-9999-999999999999` | 22 | Additional custom endpoint of the same earbuds; not a separate watch in this inventory, exact function unknown |

Battery UUID mapping: [Bluetooth SIG Assigned Numbers](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Assigned_Numbers/out/en/Assigned_Numbers.pdf). RFCOMM mapping: [Google Fast Pair message stream](https://developers.google.com/nearby/fast-pair/specifications/extensions/messagestream).

PnP properties did not provide a bound driver INF/provider/version for these four disabled endpoints. PnPUtil reported Disabled and did not list matching drivers for them in this scan. This does not prove that a suitable driver cannot exist elsewhere or reconstruct their original error before disablement. [Code 22](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/cm-prob-disabled) identifies the current disabled state only.

Assessment: required earbud audio is functioning, while these additional service endpoints are disabled. Keeping them disabled is reasonable if their functions are unnecessary. There is no present evidence from these four entries alone that the Bluetooth radio or earbuds are unstable. A driver update cannot be assumed to implement every advertised service. Do not enable all four merely to make their icons change.

## USB failure: observed current state

- Name: Unknown USB Device (Port Reset Failed).
- Present: true; problem code: **43**.
- Hardware and matching ID: **`USB\RESET_FAILURE`**; current placeholder VID/PID is not a usable product identity.
- Bound driver: **`usb.inf`**, Microsoft, version `10.0.26100.9444`. PnPUtil lists it as installed/best ranked for the reset-failure identity. A driver is already attached to the failure node; this is not the same as Code 28 missing-driver diagnosis.
- Logical location: **`Port_#0004.Hub_#0003`**.
- Path: **`ACPI(_SB_)#ACPI(PCI0)#ACPI(GP17)#ACPI(XHC1)#ACPI(RHUB)#ACPI(PRT4)`**.
- Parent: USB Root Hub (USB 3.0), then **AMD USB 3.10 eXtensible Host Controller - 1.20 (Microsoft)**; controller location PCI bus 115, device 0, function 4. Both parent nodes reported OK.

These logical port/hub numbers are Windows topology labels, not a verified physical rear-panel port number. Normal parent status does not exclude an individual port, connection, firmware or intermittent hardware problem. [Microsoft USB enumeration explanation](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/case-study--troubleshooting-an-unknown-usb-device-by-using-etw-and-netmon).

### Historical identity on the same logical path

| Recorded time (UTC+08:00) | PnP record |
| --- | --- |
| 2026-10-07 15:41:05.286 | Generic SuperSpeed USB Hub, `USB\VID_0BDA&PID_0411&REV_0117`, last arrival on the exact PRT4 path |
| 2026-10-07 15:41:07.872 | That hub's recorded last removal; a downstream SuperSpeed hub on PRT4 → USB(1) has similar arrival/removal timestamps |
| 2026-10-07 15:41:45.914 | Current reset-failure node's recorded last arrival on the exact PRT4 path |

The historical hub nodes are non-present now. Arrival/removal dates are recorded PnP lifecycle metadata, not proof of the first-ever failure, a physical unplug, or the identity of the current failed object.

**Working hypothesis:** the priority is the USB 3.x hub connection on this path: the hub/upstream cable, its power or the PC port/controller path. The previous SuperSpeed hub record is a stronger lead than blindly searching for an "Unknown USB Device driver." The still-working USB 2.x hub/radio path may be a companion side of the same physical hub, but that physical pairing has not been verified. Neither the hub product model nor a defective component is established.

## Next test when someone is at the PC

1. Identify which hub/dock/KVM/monitor upstream connection removes the current failed node. Save work and safely eject any downstream storage first. No physical test is possible from a read-only remote inventory.
2. Keep its downstream arrangement constant while changing the upstream data cable to a known-good compatible cable. Observe the exact failed path, not unrelated devices.
3. Test that hub directly on another suitable PC port, then on another compatible PC. Compare whether a SuperSpeed hub enumerates successfully and whether the original workload is stable.
4. If the problem follows the hub across known-good cables/PCs, investigate hub firmware/hardware. If it follows one cable, replace that cable. If multiple known-good devices fail only on one PC port/path, investigate that path. If a controlled software rollback changes the outcome, preserve its version evidence.

USB settings, controller uninstallations, selective-suspend changes and firmware flashing were not performed. The earlier Kernel-Power 41 restart remains a separate unproven causal question. [General case guide](../research/device-manager-bluetooth-usb.md) · [Main report](../README.md).
