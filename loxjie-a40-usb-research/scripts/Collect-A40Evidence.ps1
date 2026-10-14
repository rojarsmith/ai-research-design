param([ValidateRange(1,30)][int]$Days = 7)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$stamp = [DateTimeOffset]::Now.ToString('yyyyMMdd-HHmmss-fff')
$out = Join-Path $root "evidence/$stamp"
New-Item -ItemType Directory -Path $out -Force | Out-Null
$errorsFound = [System.Collections.Generic.List[string]]::new()
function Save-Section([string]$Name, [scriptblock]$Action) {
    try { $result = & $Action; ConvertTo-Json -InputObject @($result) -Depth 12 | Set-Content -LiteralPath (Join-Path $out "$Name.json") -Encoding utf8 }
    catch { $errorsFound.Add("${Name}: $($_.Exception.Message)") }
}
Save-Section 'system' {
    [pscustomobject]@{
        CapturedAt = [DateTimeOffset]::Now.ToString('o')
        TimeZone = (Get-TimeZone).Id
        OS = Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber,LastBootUpTime
        Board = Get-CimInstance Win32_BaseBoard | Select-Object Manufacturer,Product,Version
        BIOS = Get-CimInstance Win32_BIOS | Select-Object Manufacturer,SMBIOSBIOSVersion,ReleaseDate
        SessionName = $env:SESSIONNAME
    }
}
Save-Section 'devices' {
    Get-PnpDevice -PresentOnly | Where-Object { $_.Class -in @('USB','MEDIA','AudioEndpoint') -or $_.FriendlyName -match 'LOXJIE|XMOS' } | Select-Object Status,Class,FriendlyName,InstanceId,Problem
}
Save-Section 'drivers' {
    Get-CimInstance Win32_PnPSignedDriver | Where-Object { $_.DeviceName -match 'LOXJIE|XMOS|USB.*Host Controller' -or $_.DeviceID -match 'VID_152A&PID_880C' } | Select-Object DeviceName,DeviceID,DriverVersion,DriverDate,DriverProviderName,InfName,IsSigned
}
Save-Section 'usb-parent-chains' {
    $targets = Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -match '^USB\\VID_152A&PID_880C|^USB\\VID_0000&PID_0001' }
    foreach ($target in $targets) {
        $current = $target.InstanceId
        $chain = @()
        for ($i=0; $i -lt 12 -and $current; $i++) {
            $d = Get-PnpDevice -InstanceId $current
            $props = @(Get-PnpDeviceProperty -InstanceId $current | Where-Object { $_.KeyName -match 'Parent$|LocationPaths$|LocationInfo$|ProblemCode$|DriverVersion$|DriverInfPath$|Service$' } | Select-Object KeyName,Data)
            $chain += [pscustomobject]@{ Name=$d.FriendlyName; InstanceId=$current; Properties=$props }
            $current = ($props | Where-Object KeyName -eq 'DEVPKEY_Device_Parent').Data
        }
        [pscustomobject]@{ Target=$target.FriendlyName; Chain=$chain }
    }
}
Save-Section 'system-events' {
    Get-WinEvent -FilterHashtable @{LogName='System';StartTime=(Get-Date).AddDays(-$Days)} -MaxEvents 12000 | Where-Object { $_.ProviderName -match 'USB|Kernel-PnP|UserPnp|DriverFrameworks|Audio|WHEA|Kernel-Power|Power-Troubleshooter' -or $_.Message -match 'LOXJIE|XMOS|VID_152A|tusbaudio' } | Select-Object TimeCreated,Id,LevelDisplayName,ProviderName,Message
}
Save-Section 'audio-crash-events' {
    Get-WinEvent -FilterHashtable @{LogName='Application';StartTime=(Get-Date).AddDays(-$Days)} -MaxEvents 5000 | Where-Object { $_.ProviderName -match 'Application Error|Windows Error Reporting|Application Hang' -and $_.Message -match 'audiodg|audio|LOXJIE|XMOS|tusbaudio' } | Select-Object TimeCreated,Id,LevelDisplayName,ProviderName,Message
}
foreach ($log in @('Microsoft-Windows-USB-USBXHCI-Operational','Microsoft-Windows-Kernel-PnP/Configuration','Microsoft-Windows-Kernel-PnP/Device Management','Microsoft-Windows-Audio/Operational')) {
    $safeName = $log -replace '[\\/]', '-'
    Save-Section $safeName {
        $events = @(Get-WinEvent -FilterHashtable @{LogName=$log;StartTime=(Get-Date).AddDays(-$Days)} -MaxEvents 5000 -ErrorAction SilentlyContinue)
        if ($log -match 'Kernel-PnP') { $events = @($events | Where-Object { $_.Message -match 'VID_152A|LOXJIE|xmos|tusbaudio|VID_05E3&PID_0610|VEN_1B21&DEV_2426' }) }
        $events | Select-Object TimeCreated,Id,LevelDisplayName,ProviderName,Message
    }
}
Save-Section 'log-availability' {
    Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | Where-Object { $_.LogName -match 'USB|Audio|DriverFrameworks-UserMode|Kernel-PnP' } | Select-Object LogName,IsEnabled,RecordCount
}
Save-Section 'render-endpoints' {
    Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render' | ForEach-Object {
        $p = Get-ItemProperty ($_.PSPath + '\Properties')
        $n = $p.PSObject.Properties | Where-Object { $_.Value -is [string] -and $_.Value -match 'LOXJIE' }
        if ($n) {
            $values = @($p.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object { [pscustomobject]@{Key=$_.Name;Value=$_.Value} })
            [pscustomobject]@{Endpoint=$_.PSChildName; State=(Get-ItemProperty $_.PSPath).DeviceState; Properties=$values}
        }
    }
}
try { powercfg /getactivescheme | Set-Content (Join-Path $out 'power-plan.txt'); powercfg /query SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 | Add-Content (Join-Path $out 'power-plan.txt') } catch { $errorsFound.Add($_.Exception.Message) }
($errorsFound -join [Environment]::NewLine) | Set-Content (Join-Path $out 'collection-errors.txt') -Encoding utf8
Write-Output "Evidence saved: $out"
Write-Output "Collection errors: $($errorsFound.Count)"
