#Requires -Version 5.1
<#
Read-only NVMe SMART log and Identify Controller via IOCTL_STORAGE_QUERY_PROPERTY.
Uses fixed Get Log Page / Identify queries only; no pass-through, writes, tests,
formatting, firmware activation, power changes or resets. Run elevated if needed.
Reference: https://learn.microsoft.com/en-us/windows/win32/fileio/working-with-nvme-devices
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateRange(0,255)][int]$DiskNumber,
    [Parameter(Mandatory=$true)][string]$ExpectedModel,
    [switch]$IncludeErrorLog,
    [string]$OutputPath
)
$ErrorActionPreference = 'Stop'
if ($OutputPath -and (Test-Path -LiteralPath $OutputPath)) { throw 'Output file already exists; choose a new filename.' }
$targetDisk = Get-Disk -Number $DiskNumber
if ($targetDisk.BusType -ne 'NVMe' -or $targetDisk.FriendlyName.Trim() -ne $ExpectedModel.Trim()) {
    throw 'Disk model/bus does not match the requested target. No device opened.'
}
if (-not ('PcResearch.ReadOnlyNvme' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
namespace PcResearch {
  public static class ReadOnlyNvme {
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    private static extern SafeFileHandle CreateFile(string name, uint access, uint share,
      IntPtr security, uint creation, uint flags, IntPtr template);
    [DllImport("kernel32.dll", SetLastError=true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool DeviceIoControl(SafeFileHandle handle, uint code,
      byte[] input, uint inputLength, byte[] output, uint outputLength,
      out uint returned, IntPtr overlapped);
    private static void Put(byte[] buffer, int offset, uint value) {
      Buffer.BlockCopy(BitConverter.GetBytes(value), 0, buffer, offset, 4);
    }
    private static byte[] Query(int disk, int kind) {
      bool smart = kind == 0;
      bool identify = kind == 1;
      int length = identify ? 4096 : 512;
      byte[] input = new byte[48 + length];
      byte[] output = new byte[input.Length];
      Put(input, 0, smart ? 50u : 49u); // device / adapter protocol-specific property
      Put(input, 4, 0);                // PropertyStandardQuery
      Put(input, 8, 3);                // ProtocolTypeNvme
      Put(input, 12, identify ? 1u : 2u); // Identify / LogPage
      Put(input, 16, smart ? 2u : 1u);  // SMART / Identify Controller / Error Information
      Put(input, 24, 40);              // protocol-data offset relative to byte 8
      Put(input, 28, (uint)length);
      using (SafeFileHandle handle = CreateFile(@"\\.\PhysicalDrive" + disk, 0, 3,
        IntPtr.Zero, 3, 0, IntPtr.Zero)) {
        if (handle.IsInvalid) throw new Win32Exception(Marshal.GetLastWin32Error());
        uint returned;
        if (!DeviceIoControl(handle, 0x002D1400, input, (uint)input.Length,
          output, (uint)output.Length, out returned, IntPtr.Zero))
          throw new Win32Exception(Marshal.GetLastWin32Error());
        if (returned < 48 || BitConverter.ToUInt32(output, 0) != 48 ||
          BitConverter.ToUInt32(output, 4) != 48 ||
          BitConverter.ToUInt32(output, 8) != 3)
          throw new InvalidOperationException("Invalid NVMe protocol descriptor.");
        uint offset = BitConverter.ToUInt32(output, 24);
        uint actualLength = BitConverter.ToUInt32(output, 28);
        if (offset < 40 || actualLength < length || (ulong)8 + offset + (uint)length > returned)
          throw new InvalidOperationException("Truncated/invalid NVMe payload.");
        byte[] payload = new byte[length];
        Buffer.BlockCopy(output, checked(8 + (int)offset), payload, 0, length);
        return payload;
      }
    }
    public static byte[] ReadSmart(int disk) { return Query(disk, 0); }
    public static byte[] ReadController(int disk) { return Query(disk, 1); }
    public static byte[] ReadErrorLog(int disk) { return Query(disk, 2); }
  }
}
'@
}
$smartBytes = [PcResearch.ReadOnlyNvme]::ReadSmart($DiskNumber)
$controllerBytes = [PcResearch.ReadOnlyNvme]::ReadController($DiskNumber)
$errorLogBytes = $null
$errorLogFailure = $null
if ($IncludeErrorLog) {
    try { $errorLogBytes = [PcResearch.ReadOnlyNvme]::ReadErrorLog($DiskNumber) }
    catch { $errorLogFailure = $_.Exception.Message }
}
$errorLogEntries = @()
if ($errorLogBytes) {
    for ($entryIndex=0; $entryIndex -lt 8; $entryIndex++) {
        $entryOffset = $entryIndex*64
        $entryCount = [BitConverter]::ToUInt64($errorLogBytes,$entryOffset)
        if ($entryCount -eq 0) { continue }
        $entryStatus = [BitConverter]::ToUInt16($errorLogBytes,$entryOffset+12)
        $errorLogEntries += [pscustomobject]@{
            ErrorCount=$entryCount.ToString()
            StatusHex=('0x{0:X4}' -f $entryStatus)
            StatusCode=($entryStatus -shr 1) -band 255
            StatusCodeType=($entryStatus -shr 9) -band 7
            ParameterErrorLocation=[BitConverter]::ToUInt16($errorLogBytes,$entryOffset+14)
            Lba=[BitConverter]::ToUInt64($errorLogBytes,$entryOffset+16).ToString()
            NamespaceId=[BitConverter]::ToUInt32($errorLogBytes,$entryOffset+24)
        }
    }
}
function Read-UnsignedCounter([byte[]]$buffer, [int]$offset) {
    $counterBytes = New-Object byte[] 17
    [Array]::Copy($buffer, $offset, $counterBytes, 0, 16)
    return ([System.Numerics.BigInteger]::new($counterBytes)).ToString([Globalization.CultureInfo]::InvariantCulture)
}
function Convert-Kelvin([int]$value) {
    if ($value -eq 0) { return $null }
    return [Math]::Round($value - 273.15, 2)
}
$sensorValues = for ($sensorIndex=0; $sensorIndex -lt 8; $sensorIndex++) {
    $kelvin = [BitConverter]::ToUInt16($smartBytes, 200 + 2*$sensorIndex)
    [pscustomobject]@{Sensor=$sensorIndex+1;RawKelvin=$kelvin;Celsius=(Convert-Kelvin $kelvin)}
}
$result = [ordered]@{
    ObservedAt = [DateTimeOffset]::Now.ToString('o')
    DiskNumber = $DiskNumber
    Model = $targetDisk.FriendlyName.Trim()
    Firmware = $targetDisk.FirmwareVersion.Trim()
    CriticalWarning = $smartBytes[0]
    CompositeKelvin = [BitConverter]::ToUInt16($smartBytes,1)
    CompositeCelsius = Convert-Kelvin ([BitConverter]::ToUInt16($smartBytes,1))
    AvailableSparePercent = $smartBytes[3]
    AvailableSpareThreshold = $smartBytes[4]
    PercentageUsed = $smartBytes[5]
    DataUnitsRead = Read-UnsignedCounter $smartBytes 32
    DataUnitsWritten = Read-UnsignedCounter $smartBytes 48
    PowerCycles = Read-UnsignedCounter $smartBytes 112
    PowerOnHours = Read-UnsignedCounter $smartBytes 128
    UnsafeShutdowns = Read-UnsignedCounter $smartBytes 144
    MediaDataIntegrityErrors = Read-UnsignedCounter $smartBytes 160
    ErrorInformationLogEntries = Read-UnsignedCounter $smartBytes 176
    WarningCompositeTemperatureMinutes = [BitConverter]::ToUInt32($smartBytes,192)
    CriticalCompositeTemperatureMinutes = [BitConverter]::ToUInt32($smartBytes,196)
    TemperatureSensors = @($sensorValues)
    ThermalManagement1Transitions = [BitConverter]::ToUInt32($smartBytes,216)
    ThermalManagement2Transitions = [BitConverter]::ToUInt32($smartBytes,220)
    ThermalManagement1Seconds = [BitConverter]::ToUInt32($smartBytes,224)
    ThermalManagement2Seconds = [BitConverter]::ToUInt32($smartBytes,228)
    WarningCompositeThresholdCelsius = Convert-Kelvin ([BitConverter]::ToUInt16($controllerBytes,266))
    CriticalCompositeThresholdCelsius = Convert-Kelvin ([BitConverter]::ToUInt16($controllerBytes,268))
    RawSmartBase64 = [Convert]::ToBase64String($smartBytes)
    RecentErrorLogEntries = $errorLogEntries
    ErrorLogQueryFailure = $errorLogFailure
    Notes = 'Sensor roles are vendor-specific. Zero counters can be unimplemented. A healthy snapshot does not exclude intermittent link/controller failures. No controller serial number is exported.'
}
$json = $result | ConvertTo-Json -Depth 5
if ($OutputPath) {
    $json | Set-Content -LiteralPath $OutputPath -Encoding UTF8
}
$json
