#Requires -Version 5.1
<#
Queries Windows logs/settings; writes a fresh local evidence folder.
No repairs, log clearing, dump copying, network requests or uploads.
Use explicit incident offsets, matching the affected PC, not this repository.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$')]
    [string]$Start,
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$')]
    [string]$End,
    [string]$EvidenceRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) 'evidence'),
    [string[]]$ExtraLog = @()
)

$ErrorActionPreference = 'Stop'
$culture = [Globalization.CultureInfo]::InvariantCulture
$startOffset = [DateTimeOffset]::Parse($Start, $culture)
$endOffset = [DateTimeOffset]::Parse($End, $culture)
if ($endOffset -le $startOffset) { throw 'End must be later than Start.' }
if (($endOffset - $startOffset).TotalDays -gt 7) { throw 'Select a bounded window of seven days or less.' }
$rootPath = [IO.Path]::GetFullPath($EvidenceRoot)
$caseName = 'case-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8)
$casePath = Join-Path $rootPath $caseName
$null = New-Item -ItemType Directory -Path $casePath
$startUtc = $startOffset.UtcDateTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ', $culture)
$endUtc = $endOffset.UtcDateTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ', $culture)
$xpath = "*[System[TimeCreated[@SystemTime >= '$startUtc' and @SystemTime <= '$endUtc']]]"
$channels = @('System', 'Application', 'Security',
    'Microsoft-Windows-Kernel-EventTracing/Admin',
    'Microsoft-Windows-User Device Registration/Admin',
    'Microsoft-Windows-AppModel-State/Admin') + $ExtraLog
$channels = @($channels | Select-Object -Unique)
$results = @()
$allEvents = @()

foreach ($channel in $channels) {
    $record = [ordered]@{ Channel = $channel; QueryStatus = 'not-run'; Count = 0; QueryError = $null; ExportStatus = 'not-run'; ExportError = $null; File = $null }
    try {
        $metadata = Get-WinEvent -ListLog $channel -ErrorAction Stop
        # -ListLog treats names as patterns. Require an exact match before export.
        $metadata = @($metadata | Where-Object { $_.LogName -eq $channel })
        if ($metadata.Count -ne 1) { throw "Exact channel not available: $channel" }
        if (-not $metadata[0].IsEnabled) { throw "Channel disabled: $channel" }
        try {
            $events = @(Get-WinEvent -FilterHashtable @{LogName=$channel; StartTime=$startOffset.UtcDateTime; EndTime=$endOffset.UtcDateTime} -ErrorAction Stop)
            $record.QueryStatus = 'ok'
        } catch {
            if ($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*') {
                $events = @()
                $record.QueryStatus = 'no-events'
            } else { throw }
        }
        $record.Count = $events.Count
        $allEvents += $events
        $safeName = '{0:D2}.evtx' -f ($results.Count + 1)
        $evtxPath = Join-Path $casePath $safeName
        $exportOutput = & wevtutil.exe epl $channel $evtxPath "/q:$xpath" 2>&1
        if ($LASTEXITCODE -ne 0) { throw "wevtutil exit $LASTEXITCODE : $($exportOutput -join ' ')" }
        $record.ExportStatus = 'ok'
        $record.File = $safeName
    } catch {
        if ($record.QueryStatus -eq 'ok' -or $record.QueryStatus -eq 'no-events') {
            $record.ExportStatus = 'failed'
            $record.ExportError = $_.Exception.Message
        } else {
            $record.QueryStatus = 'unavailable-or-failed'
            $record.QueryError = $_.Exception.Message
        }
    }
    $results += [pscustomobject]$record
}

$allEvents = @($allEvents | Sort-Object TimeCreated, LogName, RecordId)
$xmlPath = Join-Path $casePath 'events.xml'
$xmlSettings = New-Object System.Xml.XmlWriterSettings
$xmlSettings.Indent = $true
$xmlSettings.Encoding = New-Object System.Text.UTF8Encoding($false)
$writer = [System.Xml.XmlWriter]::Create($xmlPath, $xmlSettings)
try {
    $writer.WriteStartDocument()
    $writer.WriteStartElement('Events')
    foreach ($event in $allEvents) { $writer.WriteRaw($event.ToXml()) }
    $writer.WriteEndElement()
    $writer.WriteEndDocument()
} finally { $writer.Dispose() }

$rows = @($allEvents | ForEach-Object {
    $message = $null
    try { $message = $_.Message } catch { $message = '[Message rendering failed; see XML]' }
    [pscustomobject]@{TimeUtc=$_.TimeCreated.ToUniversalTime().ToString('o'); Channel=$_.LogName; Provider=$_.ProviderName; Id=$_.Id; Level=$_.LevelDisplayName; RecordId=$_.RecordId; Message=$message}
})
ConvertTo-Json -InputObject $rows -Depth 5 | Set-Content -LiteralPath (Join-Path $casePath 'timeline.json') -Encoding UTF8

$systemStatus = 'ok'
$systemError = $null
try {
    $system = [ordered]@{
        OS = (Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber)
        Computer = (Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer, Model, TotalPhysicalMemory, AutomaticManagedPagefile)
        BIOS = (Get-CimInstance Win32_BIOS | Select-Object Manufacturer, SMBIOSBIOSVersion, ReleaseDate)
        Pagefile = @(Get-CimInstance Win32_PageFileUsage | Select-Object Name, AllocatedBaseSize, CurrentUsage)
        Volumes = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | Select-Object DeviceID, Size, FreeSpace)
        CrashControl = (Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl' | Select-Object CrashDumpEnabled, DumpFile, MinidumpDir, AlwaysKeepMemoryDump)
    }
    $system | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $casePath 'system.json') -Encoding UTF8
} catch { $systemStatus = 'failed'; $systemError = $_.Exception.Message }

$dumpStatus = 'ok'
$dumpError = $null
try {
    $dumpFiles = @()
    $locations = @((Join-Path $env:windir 'MEMORY.DMP'), (Join-Path $env:windir 'Minidump'), (Join-Path $env:windir 'LiveKernelReports'))
    foreach ($location in $locations) {
        if (Test-Path -LiteralPath $location) {
            $dumpFiles += @(Get-ChildItem -LiteralPath $location -Recurse -File -ErrorAction Stop | Where-Object { $_.Extension -eq '.dmp' } | Select-Object FullName, Length, LastWriteTimeUtc)
        }
    }
    ConvertTo-Json -InputObject $dumpFiles -Depth 4 | Set-Content -LiteralPath (Join-Path $casePath 'dump-inventory.json') -Encoding UTF8
} catch { $dumpStatus = 'failed'; $dumpError = $_.Exception.Message }

$manifest = [ordered]@{
    SchemaVersion = 1; CreatedUtc = [DateTime]::UtcNow.ToString('o')
    RequestedStart = $Start; RequestedEnd = $End; StartUtc = $startUtc; EndUtc = $endUtc
    CollectorTimeZone = [TimeZoneInfo]::Local.Id
    Channels = $results; TotalEvents = $allEvents.Count
    SystemStatus = $systemStatus; SystemError = $systemError
    DumpInventoryStatus = $dumpStatus; DumpInventoryError = $dumpError
    Privacy = 'Raw logs/XML may contain personal identifiers. Dump contents are not copied. No files uploaded.'
}
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $casePath 'manifest.json') -Encoding UTF8
Write-Output "Evidence saved: $casePath"
Write-Output 'Review manifest.json for partial failures and no-events before interpreting the evidence.'
