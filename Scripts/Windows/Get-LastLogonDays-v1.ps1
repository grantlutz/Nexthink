<#
.SYNOPSIS
    Nexthink Remote Action — Report the most recent interactive logon on the
    device and how many days have passed since it occurred.

.DESCRIPTION
    Reads successful logon events (Security event ID 4624) from the local
    Windows Security event log and reports the most recent one that matches
    the requested logon types, along with the number of whole days elapsed.

    By default only INTERACTIVE logon types are counted:
        2  Interactive        - signed in at the console
       10  RemoteInteractive  - signed in over RDP
       11  CachedInteractive  - signed in with cached domain credentials

    This is a deliberate correction to the common "newest 4624 wins" approach.
    Event ID 4624 also records service (5), network (3), and batch (4) logons,
    which occur constantly on a running device — using the newest event of any
    type reports "0 days since last logon" on a machine nobody has signed into
    for months, which is the opposite of what this action is used to find.

    Machine accounts (names ending in '$') and the well-known system accounts
    are excluded for the same reason.

    The Security log rolls over. If no matching event is found within the
    events scanned, LastLogonFound is false and the numeric outputs report 0 —
    this means "not found in the retained log", NOT "never logged on". Treat a
    false result as "unknown", not as evidence the device is unused.

    This action is READ-ONLY. It makes no change to the device.

.PARAMETER LogonTypes
    Comma-separated list of Windows logon type numbers to count.
    Default: '2,10,11' (Interactive, RemoteInteractive, CachedInteractive).
    Set to '2,3,4,5,7,8,9,10,11' to count every logon type, reproducing the
    original "newest 4624 of any type" behaviour.
    Values arrive from Nexthink as text; each entry must be a whole number
    between 0 and 11.

.PARAMETER MaxEventsToScan
    Whole number of 4624 events to read, newest first, while looking for a
    match. Default: '1000'. Accepted range: 1-100000.
    Raise it on busy servers where interactive logons are buried under service
    logons; lower it to reduce runtime on slow devices.

.OUTPUTS
    Nexthink output fields (auto-detected from the [Nxt]::WriteOutput* calls;
    the schema is fixed at 8 fields, written as the script's final step once
    all results have been gathered):

    LastLogonFound      (Bool)      True when a matching logon event was found
                                    within the events scanned.
    LastLogonTime       (DateTime)  Timestamp of the most recent matching
                                    logon. Defaults to 1970-01-01 00:00:00
                                    when none was found.
    DaysSinceLastLogon  (UInt32)    Whole days between that logon and now.
                                    0 when none was found.
    LastLogonUser       (String)    'DOMAIN\user' for that logon, or 'Unknown'
                                    when none was found.
    LastLogonType       (String)    Logon type number and friendly name, e.g.
                                    '10 (RemoteInteractive)'. 'Unknown' when
                                    none was found.
    EventsScanned       (UInt32)    Number of 4624 events actually examined.
    ExecutionTime       (String)    Completion time of the run, formatted
                                    "yyyy-MM-dd HH:mm:ss".
    ExecutionSummary    (String)    Result summary joined with " | ";
                                    "No actions performed." if none.

    Notes on output values:
    - DaysSinceLastLogon is a whole-day count (fractional days truncated), so a
      logon 30 hours ago reports 1. It is non-negative by construction; a
      future-dated event (clock skew) reports 0 rather than a negative value.
    - LastLogonFound must be checked before trusting the other fields. False
      means "no match in the retained log", which is not the same as "never".
    - EventsScanned reveals log-depth problems: if it equals MaxEventsToScan
      and nothing was found, the scan window was too small rather than the
      device being idle.
    - On an unhandled error the trap reports the error message to Nexthink and
      exits 1, marking the action as failed; outputs are not written in that
      case.

.NOTES
    Version           : 1  (iterate the -v<N> filename suffix on each change)
                        v1: initial Nexthinkified version of the raw
                            last_connected_to_AD.ps1 (kept unmodified in
                            last_connected_to_AD.ps1). Adds input parameters, a
                            deterministic 8-field output schema, logon-type
                            filtering, machine-account exclusion, and a
                            non-zero exit code on failure — the original
                            reported success even when the event log could not
                            be read.
    Execution context : Local System (REQUIRED). Reading the Security event log
                        needs administrative privileges; interactive-user
                        context will fail with an access error.
    Encoding          : UTF-8 with BOM, CRLF line endings (Nexthink requirement).
    Signing           : Sign with a code-signing certificate before production
                        use; deploy the certificate to Trusted Publishers on
                        endpoints.
    Timeout           : Scanning 1000 events is typically well under 10
                        seconds; a 120-second remote action timeout covers slow
                        devices and large scan windows.
    Scope             : Reads the LOCAL Security event log only. It does not
                        query Active Directory for lastLogon /
                        lastLogonTimestamp, despite the name of the original
                        script.
#>

# =============================================================================
# ⚠ NEXTHINK SAFETY FLAG — REVIEW BEFORE DEPLOYMENT
#
# Safety check: NO harmful actions found.
#
# This action is READ-ONLY. It queries the Windows Security event log and
# writes Nexthink outputs. It does not modify, delete, stop, disable, or
# install anything, makes no network connections, and accesses no credentials.
#
# Accuracy caveats that could lead to a WRONG DECISION being made from the
# results (not device damage, but worth understanding before acting on them):
#   - A false LastLogonFound means "no matching event in the retained log",
#     NOT "the device is unused". The Security log rolls over, and on a busy
#     device the retained history may be short. Do not decommission or reclaim
#     a device on this signal alone.
#   - Results depend entirely on the LogonTypes filter. Widening it to include
#     service and network logons will make nearly every device look recently
#     used.
# =============================================================================

#
# Input parameters definition
#
param(
    [string]$LogonTypes = '2,10,11',
    [string]$MaxEventsToScan = '1000'
)
# End of parameters definition

# Nexthink remote action output library — required for all [Nxt]::WriteOutput* calls.
Add-Type -Path "$env:NEXTHINK\RemoteActions\nxtremoteactions.dll"

# Default error trap: report the error to Nexthink and exit non-zero so the
# remote action is marked as failed.
trap {
    $host.ui.WriteErrorLine($_.ToString())
    exit 1
}

# Sentinel used when no matching logon is found, so the DateTime output always
# has a valid value and the schema stays deterministic.
$NO_LOGON_SENTINEL = [datetime]'1970-01-01 00:00:00'

# Windows logon type numbers to friendly names, for the LastLogonType output.
$logonTypeNames = @{
    0  = 'System'
    2  = 'Interactive'
    3  = 'Network'
    4  = 'Batch'
    5  = 'Service'
    7  = 'Unlock'
    8  = 'NetworkCleartext'
    9  = 'NewCredentials'
    10 = 'RemoteInteractive'
    11 = 'CachedInteractive'
}

# Well-known accounts that are never real interactive users.
$excludedAccounts = @('SYSTEM', 'LOCAL SERVICE', 'NETWORK SERVICE', 'ANONYMOUS LOGON', 'DWM-1', 'DWM-2', 'DWM-3', 'UMFD-0', 'UMFD-1', 'UMFD-2')

# All output values, initialized to safe defaults and populated as the script runs.
$script:Outputs = @{
    'LastLogonFound'     = $false
    'LastLogonTime'      = $NO_LOGON_SENTINEL
    'DaysSinceLastLogon' = [uint32]0
    'LastLogonUser'      = 'Unknown'
    'LastLogonType'      = 'Unknown'
    'EventsScanned'      = [uint32]0
    'ExecutionTime'      = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
}

$script:SummaryLines = @()

#
# Input parameter validation — every value arrives from Nexthink as text.
#
$requestedTypes = @(
    $LogonTypes -split ',' |
        ForEach-Object { $_.Trim() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
)

if ($requestedTypes.Count -eq 0) {
    throw "[Input error] 'LogonTypes' must contain at least one logon type number."
}

$logonTypeFilter = @()
foreach ($entry in $requestedTypes) {
    $parsed = $entry -as [int]
    if ($null -eq $parsed -or $parsed -lt 0 -or $parsed -gt 11) {
        throw "[Input error] 'LogonTypes' entries must be whole numbers between 0 and 11. Received: '$entry'."
    }
    $logonTypeFilter += $parsed
}
$logonTypeFilter = @($logonTypeFilter | Select-Object -Unique)

$maxEvents = $MaxEventsToScan.Trim() -as [int]
if ($null -eq $maxEvents -or $maxEvents -lt 1 -or $maxEvents -gt 100000) {
    throw "[Input error] 'MaxEventsToScan' must be a whole number between 1 and 100000. Received: '$MaxEventsToScan'."
}

#
# Read successful logon events, newest first.
#
$logonEvents = @()
try {
    $logonEvents = @(Get-WinEvent -FilterHashtable @{
        LogName = 'Security'
        ID      = 4624
    } -MaxEvents $maxEvents -ErrorAction Stop)
} catch [System.Diagnostics.Eventing.Reader.EventLogNotFoundException] {
    throw "[Environment error] The Security event log is not available on this device."
} catch [System.UnauthorizedAccessException] {
    throw "[Environment error] Access denied reading the Security event log. This action must run as Local System."
} catch {
    # Get-WinEvent throws a generic exception when the filter matches nothing.
    if ($_.Exception.Message -match 'No events were found') {
        $logonEvents = @()
    } else {
        throw "[Environment error] Unable to read the Security event log: $($_.Exception.Message)"
    }
}

$script:Outputs['EventsScanned'] = [uint32]$logonEvents.Count

#
# Find the newest event matching the requested logon types.
#
$matchedEvent    = $null
$matchedType     = $null
$matchedAccount  = $null

foreach ($logonEvent in $logonEvents) {
    $eventXml = [xml]$logonEvent.ToXml()

    $logonTypeValue = ($eventXml.Event.EventData.Data | Where-Object { $_.Name -eq 'LogonType' }).'#text'
    $logonType = $logonTypeValue -as [int]
    if ($null -eq $logonType -or $logonTypeFilter -notcontains $logonType) { continue }

    $targetUser   = ($eventXml.Event.EventData.Data | Where-Object { $_.Name -eq 'TargetUserName' }).'#text'
    $targetDomain = ($eventXml.Event.EventData.Data | Where-Object { $_.Name -eq 'TargetDomainName' }).'#text'

    if ([string]::IsNullOrWhiteSpace($targetUser)) { continue }
    # Machine accounts and well-known system accounts are not interactive users.
    if ($targetUser.EndsWith('$')) { continue }
    if ($excludedAccounts -contains $targetUser.ToUpper()) { continue }

    $matchedEvent = $logonEvent
    $matchedType  = $logonType
    $matchedAccount = if ([string]::IsNullOrWhiteSpace($targetDomain)) {
        $targetUser
    } else {
        "$targetDomain\$targetUser"
    }
    break
}

if ($null -ne $matchedEvent) {

    $logonTime = $matchedEvent.TimeCreated

    # Whole days elapsed. A future-dated event (clock skew) reports 0 rather
    # than a negative value, which the UInt32 output cannot represent.
    $elapsedDays = [int][math]::Floor(((Get-Date) - $logonTime).TotalDays)
    if ($elapsedDays -lt 0) { $elapsedDays = 0 }

    $typeName = if ($logonTypeNames.ContainsKey($matchedType)) { $logonTypeNames[$matchedType] } else { 'Unknown' }

    $script:Outputs['LastLogonFound']     = $true
    $script:Outputs['LastLogonTime']      = $logonTime
    $script:Outputs['DaysSinceLastLogon'] = [uint32]$elapsedDays
    $script:Outputs['LastLogonUser']      = $matchedAccount
    $script:Outputs['LastLogonType']      = ("{0} ({1})" -f $matchedType, $typeName)

    $script:SummaryLines += ("Last logon: {0} by {1}" -f $logonTime.ToString('yyyy-MM-dd HH:mm:ss'), $matchedAccount)
    $script:SummaryLines += ("Logon type: {0} ({1})" -f $matchedType, $typeName)
    $script:SummaryLines += ("Days since last logon: {0}" -f $elapsedDays)

} else {
    $script:SummaryLines += ("No logon of type(s) {0} found in the {1} most recent 4624 event(s)." -f `
        ($logonTypeFilter -join ','), $logonEvents.Count)

    if ($logonEvents.Count -ge $maxEvents) {
        $script:SummaryLines += 'Scan limit reached - increase MaxEventsToScan; the result is inconclusive, not proof the device is unused.'
    }
}

$script:Outputs['ExecutionTime'] = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Nexthink truncates String outputs at 1024 bytes. Truncating here instead means
# the value ends with a clear marker rather than being cut mid-word by the platform.
function Limit-NxtString ([string]$Value, [int]$MaxBytes = 1024) {
    if ([System.Text.Encoding]::UTF8.GetByteCount($Value) -le $MaxBytes) { return $Value }

    $marker = '...[truncated]'
    $budget = $MaxBytes - [System.Text.Encoding]::UTF8.GetByteCount($marker)
    $result = $Value.Substring(0, [math]::Min($Value.Length, $budget))
    while ([System.Text.Encoding]::UTF8.GetByteCount($result) -gt $budget -and $result.Length -gt 0) {
        $result = $result.Substring(0, $result.Length - 1)
    }
    return ($result + $marker)
}

# Output final results — every field is written unconditionally (deterministic schema)
function Update-EngineOutputVariables {
    [Nxt]::WriteOutputBool('LastLogonFound', [bool]$script:Outputs['LastLogonFound'])
    [Nxt]::WriteOutputDateTime('LastLogonTime', [datetime]$script:Outputs['LastLogonTime'])
    [Nxt]::WriteOutputUInt32('DaysSinceLastLogon', [uint32]$script:Outputs['DaysSinceLastLogon'])
    [Nxt]::WriteOutputString('LastLogonUser', [string]$script:Outputs['LastLogonUser'])
    [Nxt]::WriteOutputString('LastLogonType', [string]$script:Outputs['LastLogonType'])
    [Nxt]::WriteOutputUInt32('EventsScanned', [uint32]$script:Outputs['EventsScanned'])
    [Nxt]::WriteOutputString('ExecutionTime', [string]$script:Outputs['ExecutionTime'])

    $summary = if ($script:SummaryLines.Count -gt 0) { $script:SummaryLines -join ' | ' } else { 'No actions performed.' }
    [Nxt]::WriteOutputString('ExecutionSummary', (Limit-NxtString -Value $summary))
}

Update-EngineOutputVariables
exit 0
