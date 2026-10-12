# Synthetic regression checks. Overrides every diagnostic read/export command;
# does not read the actual Windows event logs, registry, CIM or dump inventory.
$ErrorActionPreference = 'Stop'
$testRoot = Join-Path (Split-Path $PSScriptRoot -Parent) ('evidence/mock-test-' + [guid]::NewGuid().ToString('N'))
function Assert-True($condition, $message) { if (-not $condition) { throw $message } }
function Get-WinEvent {
    param($ListLog, $FilterHashtable, $ErrorAction)
    if ($ListLog) {
        if ($ListLog -like '*AppModel*' -or $ListLog -like '*User Device*') { throw 'Synthetic missing channel' }
        return [pscustomobject]@{LogName=$ListLog; IsEnabled=($ListLog -notlike '*Kernel-EventTracing*')}
    }
    Assert-True ($FilterHashtable.StartTime.Kind -eq [DateTimeKind]::Utc) 'Query did not receive UTC'
    if ($FilterHashtable.LogName -eq 'Security') { throw 'Synthetic access denied' }
    if ($FilterHashtable.LogName -ne 'System') {
        Write-Error 'Synthetic empty query' -ErrorId NoMatchingEventsFound -ErrorAction Stop
    }
    $fixture = [pscustomobject]@{TimeCreated=[datetime]'2026-10-03T10:38:08Z'; LogName='System'; ProviderName='Microsoft-Windows-Kernel-Power'; Id=41; LevelDisplayName='Critical'; RecordId=123; Message='Synthetic <message> & evidence'}
    $fixture | Add-Member -MemberType ScriptMethod -Name ToXml -Value { '<Event xmlns="http://schemas.microsoft.com/win/2004/08/events/event"><System><Provider Name="Microsoft-Windows-Kernel-Power"/><EventID>41</EventID></System><EventData><Data>Synthetic &amp; evidence</Data></EventData></Event>' }
    return $fixture
}
function wevtutil.exe {
    param($operation, $channel, $destination, $query)
    Assert-True ($operation -eq 'epl') 'Collector attempted an operation other than export'
    Assert-True ($query.Contains('2026-10-03T09:20:00.0000000Z')) 'Export XPath offset conversion failed'
    if ($channel -eq 'Application') { $global:LASTEXITCODE = 5; return 'Synthetic export denied' }
    [IO.File]::WriteAllText($destination, 'Synthetic export placeholder, not real EVTX.')
    $global:LASTEXITCODE = 0
}
function Get-CimInstance { param($ClassName,$Filter) return [pscustomobject]@{Caption='Synthetic OS'; Version='test'; BuildNumber='test'} }
function Get-ItemProperty { param($LiteralPath) return [pscustomobject]@{CrashDumpEnabled=7} }
function Test-Path { param($LiteralPath) return $false }

& (Join-Path $PSScriptRoot 'Collect-Evidence.ps1') -Start '2026-10-03T17:20:00+08:00' -End '2026-10-03T18:50:00+08:00' -EvidenceRoot $testRoot -ExtraLog 'SyntheticEmpty'
$case = @(Get-ChildItem -LiteralPath $testRoot -Directory)[0]
$manifest = Get-Content -LiteralPath (Join-Path $case.FullName 'manifest.json') -Raw | ConvertFrom-Json
$timeline = @(Get-Content -LiteralPath (Join-Path $case.FullName 'timeline.json') -Raw | ConvertFrom-Json)
[xml]$xml = Get-Content -LiteralPath (Join-Path $case.FullName 'events.xml') -Raw
Assert-True ($manifest.TotalEvents -eq 1) 'Event count mismatch'
Assert-True ($xml.Events.Event.System.EventID -eq '41') 'Full XML not preserved'
Assert-True ($timeline[0].Message -eq 'Synthetic <message> & evidence') 'Message changed'
$system = $manifest.Channels | Where-Object Channel -eq 'System'
$application = $manifest.Channels | Where-Object Channel -eq 'Application'
$security = $manifest.Channels | Where-Object Channel -eq 'Security'
$empty = $manifest.Channels | Where-Object Channel -eq 'SyntheticEmpty'
Assert-True ($system.QueryStatus -eq 'ok' -and $system.ExportStatus -eq 'ok') 'Successful collection not recorded'
Assert-True ($application.QueryStatus -eq 'no-events' -and $application.ExportStatus -eq 'failed') 'Empty query/export failure not distinguished'
Assert-True ($security.QueryStatus -eq 'unavailable-or-failed' -and $security.QueryError) 'Access failure not recorded'
Assert-True ($empty.QueryStatus -eq 'no-events' -and $empty.ExportStatus -eq 'ok') 'Successful empty export not recorded'
Assert-True (@($manifest.Channels | Where-Object QueryStatus -eq 'unavailable-or-failed').Count -eq 4) 'Missing/disabled channel handling failed'
try {
    & (Join-Path $PSScriptRoot 'Collect-Evidence.ps1') -Start '2026-10-03T18:50:00+08:00' -End '2026-10-03T17:20:00+08:00' -EvidenceRoot $testRoot
    throw 'Invalid window was accepted'
} catch { Assert-True ($_.Exception.Message -eq 'End must be later than Start.') 'Unexpected invalid-window result' }
Assert-True (@(Get-ChildItem -LiteralPath $testRoot -Directory).Count -eq 1) 'Invalid input wrote evidence'
Write-Output 'PASS: UTC conversion, raw XML, messages, empty queries, access/export failures, unavailable channels and invalid-window handling.'
