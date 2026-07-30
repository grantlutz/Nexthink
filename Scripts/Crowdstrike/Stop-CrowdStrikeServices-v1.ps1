<#
.SYNOPSIS
    Nexthink Remote Action — Stop the CrowdStrike Falcon endpoint security
    services and report the outcome for each service.

.DESCRIPTION
    Stops each Windows service named in the ServiceNames parameter (by default
    the CrowdStrike Falcon services 'csagent' and 'csfalconservice') and waits
    for each one to reach the Stopped state before moving on.

    Each service is classified into exactly one outcome:
      - Stopped        : was running, and this run stopped it.
      - AlreadyStopped : was already in the Stopped state; no action taken.
      - NotFound       : the service is not installed on this device.
      - Failed         : the service exists but could not be stopped, or did
                         not reach Stopped within StopTimeoutSeconds.

    A service that is absent or already stopped is NOT a failure — the action
    is idempotent and safe to re-run. A service that exists but refuses to stop
    IS a failure: the script reports the reason to Nexthink and exits 1 after
    writing all outputs.

    Verification is done by re-reading the service state after the stop
    attempt, not by trusting that Stop-Service succeeded, so the reported
    counts reflect the device's actual state. This matters because CrowdStrike
    tamper protection can silently block or reverse a service stop.

    ⚠ This action disables endpoint security protection. See the safety flag
    block below.

.PARAMETER ServiceNames
    Comma-separated list of Windows service names to stop.
    Default: 'csagent,csfalconservice'.
    Values arrive from Nexthink as text; the script splits on commas, trims
    whitespace, drops empty entries, and removes duplicates. At least one
    non-empty name is required.

.PARAMETER StopTimeoutSeconds
    Whole number of seconds to wait for each individual service to reach the
    Stopped state before recording it as Failed. Default: '30'.
    Accepted range: 1-600. Values arrive as text and are converted to an
    integer by the script.

.OUTPUTS
    Nexthink output fields (auto-detected from the [Nxt]::WriteOutput* calls;
    the schema is fixed at 8 fields, written as the script's final step once
    all results have been gathered):

    ServicesRequested           (UInt32)  Number of distinct service names
                                          supplied after parsing.
    ServicesStopped             (UInt32)  Services this run transitioned from
                                          running to Stopped.
    ServicesAlreadyStopped      (UInt32)  Services already Stopped before the
                                          run; no action taken.
    ServicesNotFound            (UInt32)  Requested names not installed on the
                                          device.
    ServicesFailed              (UInt32)  Services present that could not be
                                          stopped within the timeout.
    AllRequestedServicesStopped (Bool)    True when no requested service is
                                          left running (failures = 0).
    ExecutionTime               (String)  Completion time of the run, formatted
                                          "yyyy-MM-dd HH:mm:ss".
    ExecutionSummary            (String)  Per-service outcomes joined with
                                          " | "; "No actions performed." if
                                          none.

    Notes on output values:
    - Counts are derived from a post-stop re-read of each service's status, so
      they describe the device state after the run rather than the return of
      Stop-Service.
    - ServicesRequested is the count AFTER de-duplication, so the four outcome
      counts always sum exactly to it.
    - AllRequestedServicesStopped is true when nothing requested is still
      running — including the case where every service was already stopped or
      not installed.
    - On an unhandled error the trap reports the error message to Nexthink and
      exits 1, marking the action as failed; outputs are not written in that
      case.

.NOTES
    Version           : 1  (iterate the -v<N> filename suffix on each change)
                        v1: initial Nexthinkified version of the raw
                            stop-crowdstrike.ps1 service-stop loop (kept
                            unmodified in stop-crowdstrike.ps1). Adds input
                            parameters, a deterministic 8-field output schema,
                            post-stop verification, and a stop timeout.
    Execution context : Local System (REQUIRED). Stopping a protected service
                        needs administrative privileges; interactive-user
                        context will fail.
    Encoding          : UTF-8 with BOM, CRLF line endings (Nexthink requirement).
    Signing           : Sign with a code-signing certificate before production
                        use; deploy the certificate to Trusted Publishers on
                        endpoints.
    Timeout           : Worst case is roughly StopTimeoutSeconds per requested
                        service. With the defaults (2 services x 30s) a
                        120-second remote action timeout gives comfortable
                        headroom.
#>

# =============================================================================
# ⚠ NEXTHINK SAFETY FLAG — REVIEW BEFORE DEPLOYMENT
#
# This script performs security-affecting actions BY DESIGN. They are
# intentional, are NOT removed, and are individually flagged inline:
#
#   1. DISABLES ENDPOINT SECURITY PROTECTION: stopping 'csagent' and
#      'csfalconservice' halts CrowdStrike Falcon's protection engine and its
#      telemetry reporting.
#      Impact:
#        - While stopped, the device is NOT protected against malware and
#          NOT reporting to the Falcon console. It is invisible to detection
#          and response for the entire period.
#        - The script does NOT restart the services. Protection stays off
#          until something else restores it (a reboot, service recovery
#          policy, or a separate action). A device that goes offline while
#          stopped may stay unprotected indefinitely.
#        - Targeting broadly leaves the whole estate unprotected at once.
#          Target narrowly and deliberately.
#
#   2. FORCED STOP CASCADES TO DEPENDENT SERVICES: Stop-Service -Force also
#      stops any service that depends on the named service, which may be more
#      than the two services requested.
#      Impact: dependent components stop without being named in the output;
#      the count of affected services can exceed ServicesRequested.
#
# NOTE: CrowdStrike tamper protection may block or immediately reverse these
# stops. This script verifies the post-stop state and reports Failed when the
# service is still running, so a "success" result reflects reality rather than
# the return code of Stop-Service.
# =============================================================================

#
# Input parameters definition
#
param(
    [string]$ServiceNames = 'csagent,csfalconservice',
    [string]$StopTimeoutSeconds = '30'
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

# All output values, initialized to safe defaults and populated as the script runs.
$script:Outputs = @{
    'ServicesRequested'           = [uint32]0
    'ServicesStopped'             = [uint32]0
    'ServicesAlreadyStopped'      = [uint32]0
    'ServicesNotFound'            = [uint32]0
    'ServicesFailed'              = [uint32]0
    'AllRequestedServicesStopped' = $false
    'ExecutionTime'               = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
}

$script:SummaryLines = @()

#
# Input parameter validation — every value arrives from Nexthink as text.
#
$requestedServices = @(
    $ServiceNames -split ',' |
        ForEach-Object { $_.Trim() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -Unique
)

if ($requestedServices.Count -eq 0) {
    throw "[Input error] 'ServiceNames' must contain at least one non-empty service name."
}

$stopTimeout = $StopTimeoutSeconds.Trim() -as [int]
if ($null -eq $stopTimeout -or $stopTimeout -lt 1 -or $stopTimeout -gt 600) {
    throw "[Input error] 'StopTimeoutSeconds' must be a whole number between 1 and 600. Received: '$StopTimeoutSeconds'."
}

$script:Outputs['ServicesRequested'] = [uint32]$requestedServices.Count

#
# Stop each requested service and verify the resulting state.
#
$stoppedCount        = 0
$alreadyStoppedCount = 0
$notFoundCount       = 0
$failedCount         = 0

foreach ($serviceName in $requestedServices) {

    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

    if ($null -eq $service) {
        $notFoundCount += 1
        $script:SummaryLines += ("{0}: not installed" -f $serviceName)
        continue
    }

    if ($service.Status -eq 'Stopped') {
        $alreadyStoppedCount += 1
        $script:SummaryLines += ("{0}: already stopped" -f $serviceName)
        continue
    }

    $failureReason = $null
    try {
        #
        # ⚠ NEXTHINK SAFETY FLAG: stops an endpoint security service, leaving
        # the device unprotected and unreported until it is restarted. -Force
        # also stops any dependent services.
        #
        Stop-Service -Name $serviceName -Force -ErrorAction Stop

        # Wait for the service to actually reach Stopped; Stop-Service returns
        # before the transition completes.
        $service.WaitForStatus(
            [System.ServiceProcess.ServiceControllerStatus]::Stopped,
            [timespan]::FromSeconds($stopTimeout)
        )
    } catch [System.ServiceProcess.TimeoutException] {
        $failureReason = "did not reach Stopped within ${stopTimeout}s"
    } catch {
        $failureReason = $_.Exception.Message
    }

    # Verify against the device rather than trusting the call above — tamper
    # protection can block or immediately reverse the stop.
    $service.Refresh()
    if ($service.Status -eq 'Stopped') {
        $stoppedCount += 1
        $script:SummaryLines += ("{0}: stopped" -f $serviceName)
    } else {
        $failedCount += 1
        if ([string]::IsNullOrWhiteSpace($failureReason)) {
            $failureReason = ("still {0} after stop attempt" -f $service.Status)
        }
        $script:SummaryLines += ("{0}: FAILED - {1}" -f $serviceName, $failureReason)
    }
}

$script:Outputs['ServicesStopped']             = [uint32]$stoppedCount
$script:Outputs['ServicesAlreadyStopped']      = [uint32]$alreadyStoppedCount
$script:Outputs['ServicesNotFound']            = [uint32]$notFoundCount
$script:Outputs['ServicesFailed']              = [uint32]$failedCount
$script:Outputs['AllRequestedServicesStopped'] = ($failedCount -eq 0)

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
    [Nxt]::WriteOutputUInt32('ServicesRequested', [uint32]$script:Outputs['ServicesRequested'])
    [Nxt]::WriteOutputUInt32('ServicesStopped', [uint32]$script:Outputs['ServicesStopped'])
    [Nxt]::WriteOutputUInt32('ServicesAlreadyStopped', [uint32]$script:Outputs['ServicesAlreadyStopped'])
    [Nxt]::WriteOutputUInt32('ServicesNotFound', [uint32]$script:Outputs['ServicesNotFound'])
    [Nxt]::WriteOutputUInt32('ServicesFailed', [uint32]$script:Outputs['ServicesFailed'])
    [Nxt]::WriteOutputBool('AllRequestedServicesStopped', [bool]$script:Outputs['AllRequestedServicesStopped'])
    [Nxt]::WriteOutputString('ExecutionTime', [string]$script:Outputs['ExecutionTime'])

    $summary = if ($script:SummaryLines.Count -gt 0) { $script:SummaryLines -join ' | ' } else { 'No actions performed.' }
    [Nxt]::WriteOutputString('ExecutionSummary', (Limit-NxtString -Value $summary))
}

Update-EngineOutputVariables

# A service that exists but could not be stopped is a real failure: report it
# to Nexthink with a non-zero exit code, after the outputs have been written.
if ($failedCount -gt 0) {
    $host.ui.WriteErrorLine(("Failed to stop {0} of {1} requested service(s): {2}" -f `
        $failedCount, $requestedServices.Count, ($script:SummaryLines -join ' | ')))
    exit 1
}

exit 0
